-- Seed data for FindMyEvent (PLAN.md §1 launch region, §5.2 taxonomy v1)

insert into regions (name, center_lat, center_lng) values
  ('Skopje', 41.9981, 21.4254);

-- Category taxonomy v1 — curated palette per docs/DESIGN.md (2026-08-21):
-- events colored, places neutral slate.
insert into categories (slug, kind, icon, color) values
  ('party',       'event', 'celebration',    '#FF3D81'),
  ('concert',     'event', 'music_note',     '#8F5BFF'),
  ('standup',     'event', 'mic',            '#19D3C5'),
  ('festival',    'event', 'festival',       '#FF7A00'),
  ('bar',         'place', 'local_bar',      '#64748B'),
  ('cigarettes',  'place', 'smoking_rooms',  '#64748B'),
  ('alcohol',     'place', 'liquor',         '#64748B'),
  ('hookah',      'place', 'air',            '#64748B'),
  ('betting',     'place', 'casino',         '#64748B'),
  ('nightshop',   'place', 'storefront',     '#64748B');
