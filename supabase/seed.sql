-- Seed data for FindMyEvent (PLAN.md §1 launch region, §5.2 taxonomy v1)

insert into regions (name, center_lat, center_lng) values
  ('Skopje', 41.9981, 21.4254);

-- Category taxonomy v1 — curated palette per docs/DESIGN.md (2026-08-21):
-- events colored, places neutral slate.
insert into categories (slug, kind, icon, color) values
  ('party',       'event', 'celebration',    '#FF4D8D'),
  ('concert',     'event', 'music_note',     '#7C5CFC'),
  ('standup',     'event', 'mic',            '#12C7B3'),
  ('festival',    'event', 'festival',       '#4DBA63'),
  ('bar',         'place', 'local_bar',      '#64748B'),
  ('cigarettes',  'place', 'smoking_rooms',  '#64748B'),
  ('alcohol',     'place', 'liquor',         '#64748B'),
  ('hookah',      'place', 'air',            '#64748B'),
  ('betting',     'place', 'casino',         '#64748B'),
  ('nightshop',   'place', 'storefront',     '#64748B');
