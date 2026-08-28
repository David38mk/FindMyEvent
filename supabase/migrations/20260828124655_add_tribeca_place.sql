-- Resolves one of the kadevecer.online scraper's unresolved venues (HANDOFF
-- 2026-08-24). Of the 4 flagged venues, only Tribeca is actually Skopje —
-- Omnia Night Club and Jojo's United are Ohrid, Gold Felicia is Bitola
-- (verified against kadevecer's own /clients/<slug> pages, addressLocality
-- field), so those three are correctly left out, not added.
--
-- Coordinates cross-checked two ways: Nominatim POI search for "Tribeca
-- Skopje" (amenity=pub, "Tribeca - Botanic Shop & Cafe") and MapTiler
-- geocoding of the street address from kadevecer's own page (Булевар
-- Илинден 104) — both land in the same spot (~400m apart, same block).
--
-- name is exactly 'Tribeca' (not the longer OSM display name) so it matches
-- the scraper's case-insensitive venue-name lookup in
-- supabase/functions/scrape-kadevecer/index.ts.

insert into places (region_id, category_id, name, geog, address, phone)
select r.id, c.id, 'Tribeca', st_point(21.4113588, 42.0072144)::geography,
       'Булевар Илинден 104', '+38970303413'
from regions r, categories c
where r.name = 'Skopje' and c.slug = 'bar';
