-- Seed data for FindMyEvent (PLAN.md §1 launch region, §5.2 taxonomy v1)

insert into regions (name, center_lat, center_lng) values
  ('Skopje', 41.9981, 21.4254);

-- Category taxonomy v1 (icon/color are placeholders — swap once product settles on a palette)
insert into categories (slug, kind, icon, color) values
  ('party',       'event', 'celebration',    '#E91E63'),
  ('concert',     'event', 'music_note',     '#9C27B0'),
  ('standup',     'event', 'mic',            '#FF9800'),
  ('festival',    'event', 'festival',       '#F44336'),
  ('bar',         'place', 'local_bar',      '#3F51B5'),
  ('cigarettes',  'place', 'smoking_rooms',  '#607D8B'),
  ('alcohol',     'place', 'liquor',         '#795548'),
  ('hookah',      'place', 'air',            '#009688'),
  ('betting',     'place', 'casino',         '#4CAF50'),
  ('nightshop',   'place', 'storefront',     '#FFC107');
