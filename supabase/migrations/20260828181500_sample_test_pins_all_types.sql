-- Test/QA seed: 3 sample pins for every category (place + event), so the
-- map/clustering can be visually exercised across all pin types at once.
-- Same convention as the existing [SAMPLE] dev seed (20260818150000):
-- title/name prefixed '[SAMPLE]', remove before launch with
--   delete from events where title like '[SAMPLE]%';
--   delete from places where name like '[SAMPLE]%';
-- Coordinates are scattered across central Skopje, not real venues.

insert into places (region_id, category_id, name, geog, address)
select r.id, c.id, v.name, st_point(v.lng, v.lat)::geography, 'Test data'
from (values
  ('[SAMPLE] Bar 1',              'bar',        41.9975, 21.4275),
  ('[SAMPLE] Bar 2',              'bar',        41.9998, 21.4310),
  ('[SAMPLE] Bar 3',              'bar',        41.9950, 21.4240),

  ('[SAMPLE] Alcohol Shop 1',     'alcohol',    42.0020, 21.4180),
  ('[SAMPLE] Alcohol Shop 2',     'alcohol',    42.0045, 21.4215),
  ('[SAMPLE] Alcohol Shop 3',     'alcohol',    41.9995, 21.4150),

  ('[SAMPLE] Betting Shop 1',     'betting',    41.9920, 21.4330),
  ('[SAMPLE] Betting Shop 2',     'betting',    41.9945, 21.4365),
  ('[SAMPLE] Betting Shop 3',     'betting',    41.9895, 21.4300),

  ('[SAMPLE] Cigarette Shop 1',   'cigarettes', 42.0070, 21.4400),
  ('[SAMPLE] Cigarette Shop 2',   'cigarettes', 42.0095, 21.4435),
  ('[SAMPLE] Cigarette Shop 3',   'cigarettes', 42.0045, 21.4370),

  ('[SAMPLE] Hookah Lounge 1',    'hookah',     41.9860, 21.4080),
  ('[SAMPLE] Hookah Lounge 2',    'hookah',     41.9885, 21.4115),
  ('[SAMPLE] Hookah Lounge 3',    'hookah',     41.9835, 21.4050),

  ('[SAMPLE] Night Shop 1',       'nightshop',  42.0130, 21.4470),
  ('[SAMPLE] Night Shop 2',       'nightshop',  42.0155, 21.4505),
  ('[SAMPLE] Night Shop 3',       'nightshop',  42.0105, 21.4440)
) as v(name, cat, lat, lng)
join regions r on r.name = 'Skopje'
join categories c on c.slug = v.cat;

insert into events (region_id, category_id, title, geog, starts_at, ends_at, status, source)
select r.id, c.id, v.title, st_point(v.lng, v.lat)::geography,
       current_date + v.start_offset, current_date + v.end_offset,
       'approved', 'curator'
from (values
  ('[SAMPLE] Concert 1',  'concert',  41.9700, 21.4200, interval '20 hours',          interval '23 hours'),
  ('[SAMPLE] Concert 2',  'concert',  41.9725, 21.4235, interval '1 day 20 hours',     interval '1 day 23 hours'),
  ('[SAMPLE] Concert 3',  'concert',  41.9675, 21.4165, interval '2 days 20 hours',    interval '2 days 23 hours'),

  ('[SAMPLE] Festival 1', 'festival', 42.0200, 21.3950, interval '18 hours',           interval '1 day 2 hours'),
  ('[SAMPLE] Festival 2', 'festival', 42.0225, 21.3985, interval '1 day 18 hours',     interval '2 days 2 hours'),
  ('[SAMPLE] Festival 3', 'festival', 42.0175, 21.3915, interval '2 days 18 hours',    interval '3 days 2 hours'),

  ('[SAMPLE] Party 1',    'party',    41.9600, 21.4450, interval '22 hours',           interval '1 day 4 hours'),
  ('[SAMPLE] Party 2',    'party',    41.9625, 21.4485, interval '1 day 22 hours',     interval '2 days 4 hours'),
  ('[SAMPLE] Party 3',    'party',    41.9575, 21.4415, interval '2 days 22 hours',    interval '3 days 4 hours'),

  ('[SAMPLE] Standup 1',  'standup',  42.0300, 21.4600, interval '21 hours',           interval '23 hours'),
  ('[SAMPLE] Standup 2',  'standup',  42.0325, 21.4635, interval '1 day 21 hours',     interval '1 day 23 hours'),
  ('[SAMPLE] Standup 3',  'standup',  42.0275, 21.4565, interval '2 days 21 hours',    interval '2 days 23 hours')
) as v(title, cat, lat, lng, start_offset, end_offset)
join regions r on r.name = 'Skopje'
join categories c on c.slug = v.cat;
