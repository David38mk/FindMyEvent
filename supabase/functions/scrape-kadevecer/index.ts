// Daily scraper: pulls tonight's/upcoming listings from kadevecer.online
// (a Skopje nightlife aggregator, robots.txt explicitly allows /events) and
// inserts them as pending events for curator review (ADR 0003).
//
// Runs via pg_cron (see supabase/migrations/*_kadevecer_source_and_cron.sql),
// service-role auth. Uses the service role client so it bypasses RLS —
// appropriate here since this is a trusted backend job, not a user request.
//
// Fetches the page's raw server-rendered HTML directly (Rails app, no JS
// execution needed — confirmed by inspecting the response) and parses the
// `.pre-nye-card` markup. Deliberately not routed through a third-party
// reader/proxy: the first version used r.jina.ai and got blocked (HTTP 403)
// specifically when called from Supabase's egress IPs, even though it works
// fine from an ordinary machine — fetching the source directly removes that
// dependency and its IP-reputation risk entirely.
//
// Venue resolution: events only get inserted when their venue name matches
// an existing Skopje `places` row (case-insensitive). This is deliberate,
// not a limitation to "fix" — it doubles as the Skopje-only filter (the
// source also lists Ohrid etc., with no per-event city field) and avoids
// guessing coordinates for venues we haven't verified. Unresolved venue
// names come back in the response so a curator can add them as Places once;
// future runs then pick up their events automatically.

import { createClient } from "jsr:@supabase/supabase-js@2";

const EVENTS_URL = "https://www.kadevecer.online/events";
const SITE_ORIGIN = "https://www.kadevecer.online";

interface ParsedEvent {
  title: string;
  venueName: string;
  venueType: string;
  date: string; // DD.MM.YYYY
  time: string; // HH:MM
  url: string;
}

const HTML_ENTITIES: Record<string, string> = {
  "&#39;": "'",
  "&apos;": "'",
  "&quot;": '"',
  "&amp;": "&",
  "&lt;": "<",
  "&gt;": ">",
  "&nbsp;": " ",
};

function decodeHtmlEntities(text: string): string {
  return text.replace(/&#39;|&apos;|&quot;|&amp;|&lt;|&gt;|&nbsp;/g, (e) => HTML_ENTITIES[e]);
}

function parseEvents(html: string): ParsedEvent[] {
  const results: ParsedEvent[] = [];
  // One <a href="/events/...">...<div class="pre-nye-card__badge">Type</div>
  // ...<p class="pre-nye-card__eyebrow">Day · HH:MM</p>...
  // <h3 class="pre-nye-card__title...">Title</h3>...
  // <p class="pre-nye-card__venue">📍 Venue</p>...
  // <p class="pre-nye-card__time">🗓️ DD.MM.YYYY</p> per card.
  const cardRe =
    /<a[^>]+href="(\/events\/[^"]+)"[\s\S]*?pre-nye-card__badge">\s*([^<]+?)\s*<\/div>[\s\S]*?pre-nye-card__eyebrow">[^·<]*·\s*(\d{2}:\d{2})<\/p>[\s\S]*?pre-nye-card__title[^"]*">\s*([^<]+?)\s*<\/h3>[\s\S]*?pre-nye-card__venue">\s*📍\s*([^<]+?)\s*<\/p>[\s\S]*?pre-nye-card__time">\s*🗓️\s*(\d{2}\.\d{2}\.\d{4})\s*<\/p>/g;

  let m: RegExpExecArray | null;
  while ((m = cardRe.exec(html)) !== null) {
    const [, href, venueType, time, title, venueName, date] = m;
    results.push({
      title: decodeHtmlEntities(title.trim()),
      venueName: decodeHtmlEntities(venueName.trim()),
      venueType: decodeHtmlEntities(venueType.trim()),
      time,
      date,
      url: SITE_ORIGIN + href,
    });
  }
  return results;
}

function guessCategorySlug(venueType: string, title: string): string {
  const t = `${title} ${venueType}`.toLowerCase();
  if (t.includes("concert") || t.includes("концерт")) return "concert";
  if (t.includes("festival") || t.includes("фестивал")) return "festival";
  if (t.includes("standup") || t.includes("стендап") || t.includes("stand-up")) return "standup";
  return "party";
}

function toStartsAt(date: string, time: string): string {
  const [day, month, year] = date.split(".").map(Number);
  const [hour, minute] = time.split(":").map(Number);
  const pad = (n: number) => String(n).padStart(2, "0");
  // Fixed UTC+2 offset (Skopje local, CEST-equivalent) — good enough for now,
  // same precedent as the day-boundary comment in the map_events RPC.
  return `${year}-${pad(month)}-${pad(day)}T${pad(hour)}:${pad(minute)}:00+02:00`;
}

Deno.serve(async (_req) => {
  try {
    const pageRes = await fetch(EVENTS_URL, {
      headers: { "User-Agent": "Mozilla/5.0 (compatible; FindMyEventBot/1.0)" },
    });
    if (!pageRes.ok) {
      return new Response(
        JSON.stringify({ error: `source fetch failed: ${pageRes.status}` }),
        { status: 502, headers: { "Content-Type": "application/json" } },
      );
    }
    const html = await pageRes.text();
    const parsed = parseEvents(html);

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: region, error: regionErr } = await supabase
      .from("regions").select("id").eq("name", "Skopje").single();
    if (regionErr || !region) throw new Error(`Skopje region lookup failed: ${regionErr?.message}`);

    const [{ data: places }, { data: categories }, { data: existing }] = await Promise.all([
      supabase.from("places").select("id, name").eq("region_id", region.id),
      supabase.from("categories").select("id, slug").eq("kind", "event"),
      supabase.from("events").select("source_url").eq("source", "scraper"),
    ]);

    const placeByName = new Map((places ?? []).map((p) => [p.name.toLowerCase(), p.id]));
    const catBySlug = new Map((categories ?? []).map((c) => [c.slug, c.id]));
    const existingUrls = new Set((existing ?? []).map((e) => e.source_url));

    let inserted = 0;
    let skippedDuplicate = 0;
    const unresolvedVenues = new Set<string>();

    for (const ev of parsed) {
      if (existingUrls.has(ev.url)) {
        skippedDuplicate++;
        continue;
      }
      const placeId = placeByName.get(ev.venueName.toLowerCase());
      if (!placeId) {
        unresolvedVenues.add(ev.venueName);
        continue;
      }

      const categoryId = catBySlug.get(guessCategorySlug(ev.venueType, ev.title)) ??
        catBySlug.get("party");

      const { error } = await supabase.from("events").insert({
        region_id: region.id,
        category_id: categoryId,
        title: ev.title,
        place_id: placeId,
        starts_at: toStartsAt(ev.date, ev.time),
        status: "pending",
        source: "scraper",
        source_url: ev.url,
      });
      if (!error) {
        inserted++;
        existingUrls.add(ev.url);
      }
    }

    return new Response(
      JSON.stringify({
        parsed: parsed.length,
        inserted,
        skippedDuplicate,
        unresolvedVenues: [...unresolvedVenues],
      }),
      { headers: { "Content-Type": "application/json" } },
    );
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
