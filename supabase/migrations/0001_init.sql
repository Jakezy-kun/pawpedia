-- ============================================================================
-- PawPedia — initial schema
-- ============================================================================
-- Supabase Auth owns auth.users. We never create our own users table; extra
-- profile fields live in public.profiles, keyed 1:1 off auth.users.id.
--
-- Breeds are NOT in this database. They live in a MySQL database on Freehostia
-- and are read over HTTP. That is why favorites.breed_id has no foreign key.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  name        text not null,
  photo_url   text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on table public.profiles is
  'Extra user data, 1:1 with auth.users. Created automatically by the on_auth_user_created trigger.';

-- ---------------------------------------------------------------------------
-- favorites
-- ---------------------------------------------------------------------------
-- breed_id is deliberately not a foreign key: breeds live in a different
-- system entirely. We store a display snapshot (name/group/picture) so the
-- Favorites grid renders from one query instead of N calls to the breed API.
create table if not exists public.favorites (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  breed_id    int  not null,
  breed_name  text not null,
  breed_group text,
  picture     text,
  created_at  timestamptz not null default now(),
  unique (user_id, breed_id)
);

comment on column public.favorites.breed_id is
  'Primary key from the MySQL breeds database on Freehostia. Intentionally not a foreign key.';

-- Favorites are always read as "everything for the current user, newest first".
create index if not exists favorites_user_id_created_at_idx
  on public.favorites (user_id, created_at desc);

-- ---------------------------------------------------------------------------
-- keep profiles.updated_at honest
-- ---------------------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_touch_updated_at on public.profiles;
create trigger profiles_touch_updated_at
  before update on public.profiles
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- auto-create a profile row on sign-up
-- ---------------------------------------------------------------------------
-- The Flutter app passes the display name through signUp(data: {'name': ...}),
-- which lands in raw_user_meta_data.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, name)
  values (new.id, coalesce(nullif(trim(new.raw_user_meta_data->>'name'), ''), 'PawPedia User'))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Row Level Security — NOT optional.
-- ---------------------------------------------------------------------------
-- The Flutter app ships with the anon key, which is public by design. Without
-- RLS, anyone holding that key could read or delete every user's rows.
alter table public.profiles  enable row level security;
alter table public.favorites enable row level security;

-- profiles: a user may only touch their own row.
drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles
  for insert with check (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists "profiles_delete_own" on public.profiles;
create policy "profiles_delete_own" on public.profiles
  for delete using (auth.uid() = id);

-- favorites: a user may only touch their own rows.
drop policy if exists "favorites_select_own" on public.favorites;
create policy "favorites_select_own" on public.favorites
  for select using (auth.uid() = user_id);

drop policy if exists "favorites_insert_own" on public.favorites;
create policy "favorites_insert_own" on public.favorites
  for insert with check (auth.uid() = user_id);

drop policy if exists "favorites_update_own" on public.favorites;
create policy "favorites_update_own" on public.favorites
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "favorites_delete_own" on public.favorites;
create policy "favorites_delete_own" on public.favorites
  for delete using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- Storage: avatars
-- ---------------------------------------------------------------------------
-- Public-read so profiles.photo_url can be rendered by cached_network_image
-- without signing every URL. Writes are restricted to the owning user, whose
-- id must be the first path segment: avatars/{user_id}/avatar.jpg
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

drop policy if exists "avatars_public_read" on storage.objects;
create policy "avatars_public_read" on storage.objects
  for select using (bucket_id = 'avatars');

drop policy if exists "avatars_insert_own" on storage.objects;
create policy "avatars_insert_own" on storage.objects
  for insert with check (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "avatars_update_own" on storage.objects;
create policy "avatars_update_own" on storage.objects
  for update using (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "avatars_delete_own" on storage.objects;
create policy "avatars_delete_own" on storage.objects
  for delete using (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );
