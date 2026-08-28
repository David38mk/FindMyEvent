-- Dedicated Supabase Auth account for ig-scraper's publish_events.py
-- (tracked outside this repo -- see its CLAUDE.md), which turns scraped
-- Instagram captions into `pending` FindMyEvent events fully
-- automatically. It authenticates as this account and inserts under
-- RLS's existing "organizers insert pending events" policy (initial
-- schema) -- deliberately NOT the service_role key, which is meant to
-- exist only inside Supabase's own Edge Function sandbox (see
-- scrape-kadevecer's function comment), never in a file on a local
-- machine. This account can only ever insert its own status='pending'
-- events; it cannot update, approve, or delete anything -- that's
-- enforced by RLS, not by publish_events.py's own logic.
--
-- Password is a generated, random, throwaway credential stored only in
-- ig-scraper's local .env (gitignored, never committed) -- there is
-- nothing else this account can access, so its blast radius if leaked is
-- limited to inserting spurious pending events (visible to curators
-- before anything goes live, and always attributable to this one
-- account).
--
-- This mirrors an account already created imperatively via the
-- Management API on 2026-08-28; this migration documents it for the
-- repo's history and is written idempotently in case of a replay.
do $$
declare
  v_user_id uuid;
begin
  select id into v_user_id from auth.users where email = 'ig-scraper-bot@findmyevent.local';

  if v_user_id is null then
    v_user_id := gen_random_uuid();

    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      created_at, updated_at, raw_app_meta_data, raw_user_meta_data,
      is_super_admin, confirmation_token, email_change, email_change_token_new, recovery_token
    ) values (
      '00000000-0000-0000-0000-000000000000', v_user_id, 'authenticated', 'authenticated',
      'ig-scraper-bot@findmyevent.local', crypt(gen_random_uuid()::text, gen_salt('bf')), now(),
      now(), now(), '{"provider":"email","providers":["email"]}'::jsonb,
      '{"purpose":"ig-scraper automated event submission bot"}'::jsonb,
      false, '', '', '', ''
    );

    insert into auth.identities (
      id, provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at
    ) values (
      gen_random_uuid(), v_user_id::text, v_user_id,
      jsonb_build_object('sub', v_user_id::text, 'email', 'ig-scraper-bot@findmyevent.local'),
      'email', now(), now(), now()
    );
    -- Note: a fresh run of this migration generates its own random
    -- password (unrecoverable, never logged) -- set a real one via the
    -- Admin API or dashboard afterward if replaying this from scratch.
    -- The original run's actual password lives only in ig-scraper's
    -- local .env.
  end if;

  update public.profiles set role = 'organizer' where user_id = v_user_id;
end;
$$;
