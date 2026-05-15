-- =============================================================================
-- Family Score: Initial Schema
-- Phase 1 Foundation
-- =============================================================================

-- Enable required extensions
create extension if not exists "pgcrypto";  -- gen_random_uuid(), gen_random_bytes()

-- =============================================================================
-- TABLE: families
-- =============================================================================
create table public.families (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  created_at  timestamptz not null default now(),
  created_by  uuid references auth.users(id) on delete set null
);

-- =============================================================================
-- TABLE: family_members (erweitertes Profil, 1:1 mit auth.users)
-- =============================================================================
create table public.family_members (
  id            uuid primary key references auth.users(id) on delete cascade,
  family_id     uuid references public.families(id) on delete set null,
  display_name  text not null,
  avatar_color  text not null default '#4A90D9',
  role          text not null default 'adult'
                  check (role in ('admin', 'adult', 'child')),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.family_members (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', 'New Member'));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- =============================================================================
-- TABLE: category_config
-- =============================================================================
create table public.category_config (
  id            uuid primary key default gen_random_uuid(),
  family_id     uuid not null references public.families(id) on delete cascade,
  name          text not null,
  icon          text,
  color         text,
  point_weight  numeric(5,2) not null default 1.0,
  is_enabled    boolean not null default true,
  sort_order    int not null default 0,
  created_at    timestamptz not null default now(),
  unique (family_id, name)
);

-- =============================================================================
-- TABLE: activity_entries (append-only, Score NIEMALS als mutabler Wert)
-- =============================================================================
create table public.activity_entries (
  id                uuid primary key default gen_random_uuid(),
  family_id         uuid not null references public.families(id) on delete cascade,
  user_id           uuid not null references auth.users(id) on delete cascade,
  category_id       uuid not null references public.category_config(id),
  duration_minutes  int not null check (duration_minutes > 0),
  points            numeric(8,2) not null check (points >= 0),
  title             text,
  logged_at         timestamptz not null default now(),
  created_at        timestamptz not null default now()
);

create index activity_entries_family_user_logged
  on public.activity_entries(family_id, user_id, logged_at desc);

-- =============================================================================
-- TABLE: family_invites
-- =============================================================================
create table public.family_invites (
  id          uuid primary key default gen_random_uuid(),
  family_id   uuid not null references public.families(id) on delete cascade,
  created_by  uuid not null references auth.users(id) on delete cascade,
  role        text not null default 'adult'
                check (role in ('admin', 'adult', 'child')),
  token       text not null unique
                default encode(gen_random_bytes(12), 'base64'),
  used_by     uuid references auth.users(id) on delete set null,
  used_at     timestamptz,
  expires_at  timestamptz not null default (now() + interval '7 days'),
  created_at  timestamptz not null default now()
);

-- =============================================================================
-- TABLE: weekly_summaries (materialisiert via DB-Trigger, NIEMALS Client-seitig)
-- =============================================================================
create table public.weekly_summaries (
  id              uuid primary key default gen_random_uuid(),
  family_id       uuid not null references public.families(id) on delete cascade,
  user_id         uuid not null references auth.users(id) on delete cascade,
  week_start      date not null,
  total_minutes   int not null default 0,
  total_points    numeric(10,2) not null default 0,
  by_category     jsonb,
  updated_at      timestamptz not null default now(),
  unique (family_id, user_id, week_start)
);

-- =============================================================================
-- DB TRIGGER: activity_entries → weekly_summaries (Upsert bei INSERT/DELETE)
-- NIEMALS inkrementell — immer vollständige Neuberechnung
-- =============================================================================
create or replace function public.update_weekly_summary()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_family_id     uuid;
  v_user_id       uuid;
  v_week_start    date;
  v_total_minutes int;
  v_total_points  numeric(10,2);
  v_by_category   jsonb;
begin
  if (TG_OP = 'DELETE') then
    v_family_id  := OLD.family_id;
    v_user_id    := OLD.user_id;
    v_week_start := date_trunc('week', OLD.logged_at)::date;
  else
    v_family_id  := NEW.family_id;
    v_user_id    := NEW.user_id;
    v_week_start := date_trunc('week', NEW.logged_at)::date;
  end if;

  -- Total aggregates for the week (full recalculation, never incremental)
  select
    coalesce(sum(ae.duration_minutes), 0),
    coalesce(sum(ae.points), 0)
  into v_total_minutes, v_total_points
  from public.activity_entries ae
  where ae.family_id  = v_family_id
    and ae.user_id    = v_user_id
    and date_trunc('week', ae.logged_at)::date = v_week_start;

  -- Per-category breakdown
  select jsonb_object_agg(
    category_id::text,
    jsonb_build_object('minutes', cat_minutes, 'points', cat_points)
  )
  into v_by_category
  from (
    select
      ae.category_id,
      sum(ae.duration_minutes) as cat_minutes,
      sum(ae.points) as cat_points
    from public.activity_entries ae
    where ae.family_id  = v_family_id
      and ae.user_id    = v_user_id
      and date_trunc('week', ae.logged_at)::date = v_week_start
    group by ae.category_id
  ) cat_data;

  insert into public.weekly_summaries
    (family_id, user_id, week_start, total_minutes, total_points, by_category, updated_at)
  values
    (v_family_id, v_user_id, v_week_start, v_total_minutes, v_total_points, v_by_category, now())
  on conflict (family_id, user_id, week_start)
  do update set
    total_minutes = excluded.total_minutes,
    total_points  = excluded.total_points,
    by_category   = excluded.by_category,
    updated_at    = now();

  return null;
end;
$$;

create trigger on_activity_entry_change
  after insert or delete on public.activity_entries
  for each row execute procedure public.update_weekly_summary();

-- =============================================================================
-- REALTIME PUBLICATIONS
-- =============================================================================
alter publication supabase_realtime add table public.activity_entries;
alter publication supabase_realtime add table public.weekly_summaries;
alter publication supabase_realtime add table public.family_members;

-- =============================================================================
-- INDEXES
-- =============================================================================
create index family_members_family_id on public.family_members(family_id);
create index family_members_user_family on public.family_members(id, family_id);
create index category_config_family_id on public.category_config(family_id);
create index family_invites_token on public.family_invites(token);
create index weekly_summaries_family_user_week
  on public.weekly_summaries(family_id, user_id, week_start);

-- =============================================================================
-- HELPER FUNCTIONS (security definer — rufen auth.uid() einmal auf, nicht pro Row)
-- =============================================================================

create or replace function public.is_family_member(p_family_id uuid)
returns boolean
language sql
security definer
set search_path = ''
as $$
  select exists(
    select 1 from public.family_members
    where id        = (select auth.uid())
      and family_id = p_family_id
  );
$$;

create or replace function public.is_family_admin(p_family_id uuid)
returns boolean
language sql
security definer
set search_path = ''
as $$
  select exists(
    select 1 from public.family_members
    where id        = (select auth.uid())
      and family_id = p_family_id
      and role      = 'admin'
  );
$$;

-- =============================================================================
-- RLS: families
-- =============================================================================
alter table public.families enable row level security;

create policy "Familienmitglieder koennen Familie lesen"
  on public.families for select to authenticated
  using (public.is_family_member(id));

create policy "Admin kann Familie aktualisieren"
  on public.families for update to authenticated
  using (public.is_family_admin(id));

create policy "Authentifizierter User kann Familie erstellen"
  on public.families for insert to authenticated
  with check (created_by = (select auth.uid()));

-- =============================================================================
-- RLS: family_members
-- =============================================================================
alter table public.family_members enable row level security;

create policy "Familienmitglieder sehen sich gegenseitig"
  on public.family_members for select to authenticated
  using (
    id = (select auth.uid())
    or
    public.is_family_member(family_id)
  );

create policy "User verwaltet eigenes Profil"
  on public.family_members for update to authenticated
  using ((select auth.uid()) = id);

create policy "Admin verwaltet Familienmitglieder"
  on public.family_members for all to authenticated
  using (public.is_family_admin(family_id));

create policy "User kann eigenes Profil initialisieren"
  on public.family_members for insert to authenticated
  with check ((select auth.uid()) = id);

-- =============================================================================
-- RLS: category_config
-- =============================================================================
alter table public.category_config enable row level security;

create policy "Familienmitglieder lesen Kategorien"
  on public.category_config for select to authenticated
  using (public.is_family_member(family_id));

create policy "Admin verwaltet Kategorien"
  on public.category_config for all to authenticated
  using (public.is_family_admin(family_id));

-- =============================================================================
-- RLS: activity_entries
-- =============================================================================
alter table public.activity_entries enable row level security;

create policy "Familienmitglieder lesen alle Eintraege der Familie"
  on public.activity_entries for select to authenticated
  using (public.is_family_member(family_id));

create policy "User erstellt eigene Eintraege"
  on public.activity_entries for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and public.is_family_member(family_id)
  );

create policy "User loescht eigene Eintraege"
  on public.activity_entries for delete to authenticated
  using (
    (select auth.uid()) = user_id
  );

create policy "Admin loescht alle Eintraege der Familie"
  on public.activity_entries for delete to authenticated
  using (public.is_family_admin(family_id));

-- =============================================================================
-- RLS: family_invites
-- =============================================================================
alter table public.family_invites enable row level security;

create policy "Admin verwaltet Einladungen"
  on public.family_invites for all to authenticated
  using (public.is_family_admin(family_id));

-- CR-01 fix: restrict to family members + invite creator (no token exposure to unrelated users)
create policy "Familienmitglieder und Ersteller koennen Einladungen lesen"
  on public.family_invites for select to authenticated
  using (
    public.is_family_member(family_id)
    OR created_by = (SELECT auth.uid())
  );

-- =============================================================================
-- RLS: weekly_summaries
-- =============================================================================
alter table public.weekly_summaries enable row level security;

create policy "Familienmitglieder lesen Weekly Summaries"
  on public.weekly_summaries for select to authenticated
  using (public.is_family_member(family_id));

create policy "Service kann Weekly Summaries upserten"
  on public.weekly_summaries for all to service_role
  using (true);
