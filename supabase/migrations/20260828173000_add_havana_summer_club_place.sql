-- Resolves the venue for the new IG mirror-scraper pipeline (ig-scraper's
-- mirror_scrape.py + publish_events.py, tracked outside this repo). Its
-- accounts.txt maps the havana.summer.club Instagram account to the venue
-- name "Havana Summer Club" -- publish_events.py resolves place_id by an
-- exact case-insensitive match against this name, same convention as the
-- kadevecer scraper.
--
-- Coordinates cross-checked two ways: Nominatim POI search for "Havana
-- Summer Club Skopje" (amenity=nightclub, exact name match) and a direct
-- Overpass query of that same OSM way (id 1429502547) -- both return the
-- same point to within rounding (42.00696, 21.42046).
--
-- name is exactly 'Havana Summer Club' (not a longer/shorter variant) so it
-- matches accounts.txt's venue field and the scraper's case-insensitive
-- lookup.

insert into places (region_id, category_id, name, geog, address)
select r.id, c.id, 'Havana Summer Club', st_point(21.4204619, 42.0069637)::geography,
       'Столтенбергова, Карпош 1'
from regions r, categories c
where r.name = 'Skopje' and c.slug = 'bar';
