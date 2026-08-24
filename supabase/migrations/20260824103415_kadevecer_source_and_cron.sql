-- Register kadevecer.online as a Source (ADR 0003) and schedule the daily
-- scraper Edge Function (supabase/functions/scrape-kadevecer).

insert into sources (name, url, trust, enabled)
values ('Kade Vecer', 'https://www.kadevecer.online', 'trusted', true);

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- MANUAL STEP REQUIRED before this cron job can authenticate (run once, in
-- the Supabase SQL editor — NOT here, and NEVER commit the key itself):
--
--   select vault.create_secret('<your service_role key>', 'scrape_kadevecer_auth');
--
-- The service_role key is deliberately not handled by migrations/CI — it
-- bypasses RLS entirely, same reason it's kept out of dart_defines.json.

select cron.schedule(
  'scrape-kadevecer-daily',
  '0 3 * * *', -- 03:00 UTC daily (~04:00-05:00 Skopje local)
  $$
  select net.http_post(
    url := 'https://cojvcfyqgggcssjbbecz.supabase.co/functions/v1/scrape-kadevecer',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (
        select decrypted_secret from vault.decrypted_secrets
        where name = 'scrape_kadevecer_auth'
      )
    ),
    body := '{}'::jsonb
  );
  $$
);
