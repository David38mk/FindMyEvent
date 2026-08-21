-- Palette v2 — David's refinement of the curated palette (docs/DESIGN.md).
-- Brighter event hues for dark tiles; places move to cool slate #64748B.
update categories set color = c.color
from (values
  ('party',      '#FF4D8D'),
  ('concert',    '#7C5CFC'),
  ('standup',    '#12C7B3'),
  ('festival',   '#4DBA63'),
  ('bar',        '#64748B'),
  ('cigarettes', '#64748B'),
  ('alcohol',    '#64748B'),
  ('hookah',     '#64748B'),
  ('betting',    '#64748B'),
  ('nightshop',  '#64748B')
) as c(slug, color)
where categories.slug = c.slug;
