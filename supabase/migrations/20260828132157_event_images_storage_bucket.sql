-- Phase 2: Supabase Storage bucket for Event images (organizer submissions).
-- Bucket + its policies live in a migration so the repo keeps describing the
-- live project (HANDOFF.md "Database sync rules" #1) — creating it by hand in
-- the dashboard would be exactly the drift those rules exist to prevent.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'event-images',
  'event-images',
  -- Public: event photos are shown to anonymous browsers on the map, and a
  -- public bucket serves them from CDN-cacheable URLs with no signing round
  -- trip. events.image_url stores that public URL.
  true,
  5242880, -- 5 MB; the app downscales to ~1600px/q80 before upload, well under
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

-- Read: anyone, including anon (matches the "approved events are public" rule).
create policy "event images readable by everyone" on storage.objects
  for select
  using (bucket_id = 'event-images');

-- Write: only Organizers/Curators, and only into their own <uid>/ folder, so
-- one organizer can never overwrite another's image. Same shape as the
-- events INSERT policy (submitted_by = auth.uid()).
create policy "organizers upload event images" on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'event-images'
    and (storage.foldername(name))[1] = auth.uid()::text
    and exists (
      select 1 from public.profiles
      where user_id = auth.uid() and role in ('organizer', 'curator')
    )
  );

create policy "organizers update own event images" on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'event-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "organizers delete own event images" on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'event-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
