-- Curated palette (docs/DESIGN.md 2026-08-21): events are the only colored
-- pins on the map; places are uniform neutral slate with a white glyph.
update categories set color = c.color
from (values
  ('party',      '#E84D8A'),
  ('concert',    '#6C63FF'),
  ('standup',    '#00B8A9'),
  ('festival',   '#3FA34D'),
  ('bar',        '#5B6472'),
  ('cigarettes', '#5B6472'),
  ('alcohol',    '#5B6472'),
  ('hookah',     '#5B6472'),
  ('betting',    '#5B6472'),
  ('nightshop',  '#5B6472')
) as c(slug, color)
where categories.slug = c.slug;
