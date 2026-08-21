-- Palette v3 "Hot City" (docs/DESIGN.md, ADR 0005). Category = pin layer;
-- brand red never appears on pins. Places keep cool slate — furniture, not
-- signal (steel #9299A8 is reserved for the sold-out status badge).
update categories set color = c.color
from (values
  ('party',      '#FF3D81'),
  ('concert',    '#8F5BFF'),
  ('standup',    '#19D3C5'),
  ('festival',   '#FF7A00'),
  ('bar',        '#64748B'),
  ('cigarettes', '#64748B'),
  ('alcohol',    '#64748B'),
  ('hookah',     '#64748B'),
  ('betting',    '#64748B'),
  ('nightshop',  '#64748B')
) as c(slug, color)
where categories.slug = c.slug;
