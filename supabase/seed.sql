-- Seed data for FindMyEvent (PLAN.md §1 launch region, §5.2 taxonomy v1)

insert into regions (name, center_lat, center_lng) values
  ('Skopje', 41.9981, 21.4254);

-- Category taxonomy v1 — curated palette per docs/DESIGN.md (2026-08-21):
-- events colored, places neutral slate.
insert into categories (slug, kind, icon, color) values
  ('party',       'event', 'celebration',    '#E84D8A'),
  ('concert',     'event', 'music_note',     '#6C63FF'),
  ('standup',     'event', 'mic',            '#00B8A9'),
  ('festival',    'event', 'festival',       '#3FA34D'),
  ('bar',         'place', 'local_bar',      '#5B6472'),
  ('cigarettes',  'place', 'smoking_rooms',  '#5B6472'),
  ('alcohol',     'place', 'liquor',         '#5B6472'),
  ('hookah',      'place', 'air',            '#5B6472'),
  ('betting',     'place', 'casino',         '#5B6472'),
  ('nightshop',   'place', 'storefront',     '#5B6472');
