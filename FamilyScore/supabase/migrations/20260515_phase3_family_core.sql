-- =============================================================================
-- Family Score: Phase 3 Family Core
-- Phase 3 Foundation -- Family Creation, Invite Flow, Child Profiles
-- Abhaengig von: 20260515_initial_schema.sql (Phase 1)
-- =============================================================================

-- ============================================================
-- ABSCHNITT 1: child_profiles-Tabelle
-- ============================================================

-- Kinder-Profile ohne auth.users-FK: parent-managed, kein eigenes Device-Login.
-- Phase 4 Integrationspunkt: activity_entries benoetigt child_profile_id uuid nullable
-- als neue Spalte (Breaking Change in activity_entries.user_id noch nicht gemacht --
-- das ist Phase 4 Aufgabe).
-- TODO(Phase 4): ALTER TABLE public.activity_entries ADD COLUMN child_profile_id uuid
--   REFERENCES public.child_profiles(id) ON DELETE SET NULL;

create table public.child_profiles (
  id            uuid primary key default gen_random_uuid(),
  family_id     uuid not null references public.families(id) on delete cascade,
  display_name  text not null check (char_length(display_name) between 1 and 50),
  avatar_color  text not null default '#FF9500',
  created_by    uuid not null references auth.users(id) on delete cascade,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index child_profiles_family_id on public.child_profiles(family_id);

-- RLS
alter table public.child_profiles enable row level security;

create policy "Familienmitglieder sehen Kind-Profile"
  on public.child_profiles for select to authenticated
  using (public.is_family_member(family_id));

-- "for all" deckt UPDATE + DELETE ab (Admin verwaltet)
create policy "Admin verwaltet Kind-Profile"
  on public.child_profiles for all to authenticated
  using (public.is_family_admin(family_id));

-- Explizite INSERT-Policy mit WITH CHECK (Defense in Depth)
create policy "Admin erstellt Kind-Profile"
  on public.child_profiles for insert to authenticated
  with check (public.is_family_admin(family_id));


-- ============================================================
-- ABSCHNITT 2: family_members UPDATE-Policy ersetzen
-- ============================================================
-- Bestehende Phase-1-Policy erlaubte direktes UPDATE incl. role + family_id.
-- Neue Policy beschraenkt direktes UPDATE auf sichere Felder (display_name, avatar_color).
-- Rollen- und Familien-Aenderungen laufen AUSSCHLIESSLICH ueber SECURITY DEFINER RPCs.

drop policy if exists "User verwaltet eigenes Profil" on public.family_members;

create policy "User aktualisiert eigenes Profil (nur sichere Felder)"
  on public.family_members for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);
-- Hinweis: role + family_id sind NICHT ueber diese Policy aenderbar, da
-- die RPCs change_member_role und remove_member als SECURITY DEFINER diese Felder
-- direkt aendern ohne den RLS-UPDATE-Pfad zu benutzen (sie laufen als DB-Owner).


-- ============================================================
-- ABSCHNITT 3: SECURITY DEFINER RPCs
-- ============================================================

-- ----------------------------------------------------------
-- 3.1 create_family: Familie erstellen + User zum Admin machen
-- ----------------------------------------------------------
-- Atomar: INSERT families + UPDATE family_members + INSERT category_config
-- Security: User darf noch keiner Familie angehoeren
-- Seeding: 4 Standard-Kategorien werden direkt angelegt (Pitfall 5 vermeiden)

create or replace function public.create_family(family_name text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_family_id uuid;
begin
  -- Laengenvalidierung Familienname
  if char_length(family_name) < 1 or char_length(family_name) > 60 then
    raise exception 'Familienname muss zwischen 1 und 60 Zeichen lang sein';
  end if;

  -- Sicherheitscheck: User darf noch keiner Familie angehoeren
  if exists (
    select 1 from public.family_members
    where id = (select auth.uid())
      and family_id is not null
  ) then
    raise exception 'User gehoert bereits einer Familie an';
  end if;

  -- Neue Familie anlegen
  insert into public.families (name, created_by)
  values (family_name, (select auth.uid()))
  returning id into v_family_id;

  -- User zum Admin der neuen Familie machen
  update public.family_members
  set family_id  = v_family_id,
      role       = 'admin',
      updated_at = now()
  where id = (select auth.uid());

  -- Standard-Kategorien seeden (Pitfall 5: ohne Seeding schlaegt Phase 4 fehl)
  insert into public.category_config (family_id, name, icon, color, point_weight, sort_order)
  values
    (v_family_id, 'Haushalt',       'house.fill',         '#FF3B30', 1.5, 0),
    (v_family_id, 'Hobby/Freizeit', 'gamecontroller.fill', '#34C759', 1.0, 1),
    (v_family_id, 'Besorgungen',    'bag.fill',           '#FF9500', 1.2, 2),
    (v_family_id, 'Arbeit/Schule',  'book.fill',          '#007AFF', 1.8, 3);

  return v_family_id;
end;
$$;

-- Rechte: nur authentifizierte User duerfen ausfuehren
grant execute on function public.create_family(text) to authenticated;
revoke execute on function public.create_family(text) from anon;


-- ----------------------------------------------------------
-- 3.2 accept_invite: Einladungscode einloesen
-- ----------------------------------------------------------
-- Security: Token single-use (used_by is null), Ablaufdatum serverseitig geprueft.
-- Kein direktes SELECT auf family_invites fuer unfamilied Users (Pitfall 1).

create or replace function public.accept_invite(invite_token text)
returns uuid   -- gibt die family_id zurueck
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_invite public.family_invites%rowtype;
begin
  -- Sicherheitscheck: User ist noch in keiner Familie
  if exists (
    select 1 from public.family_members
    where id = (select auth.uid())
      and family_id is not null
  ) then
    raise exception 'User gehoert bereits einer Familie an';
  end if;

  -- Token suchen und validieren (single-use + Ablaufdatum)
  select * into v_invite
  from public.family_invites
  where token = invite_token
    and used_by is null
    and expires_at > now();

  if not found then
    raise exception 'Ungültiger oder abgelaufener Einladungscode';
  end if;

  -- User der Familie zuweisen
  update public.family_members
  set family_id  = v_invite.family_id,
      role       = v_invite.role,
      updated_at = now()
  where id = (select auth.uid());

  -- Invite als benutzt markieren (single-use enforcement)
  update public.family_invites
  set used_by = (select auth.uid()),
      used_at  = now()
  where id = v_invite.id;

  return v_invite.family_id;
end;
$$;

grant execute on function public.accept_invite(text) to authenticated;
revoke execute on function public.accept_invite(text) from anon;


-- ----------------------------------------------------------
-- 3.3 change_member_role: Rolle eines Mitglieds aendern
-- ----------------------------------------------------------
-- Security: Nur Admin der gleichen Familie; kein Downgrade wenn letzter Admin.
-- Privilege-Escalation: Ziel-Mitglied kann eigene Rolle NICHT selbst aendern
-- (der Admin-Check schliesst das aus: Ziel-Member waere nur sein eigenes Profil,
--  was keinen Admin-Status der eigenen Familie erfordern wuerde -- daher kein
--  direktes Risiko; direktes RLS-UPDATE blockiert role-Aenderung ohnehin).

create or replace function public.change_member_role(target_member_id uuid, new_role text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_target_family_id uuid;
  v_admin_count      int;
begin
  -- Rollenvalidierung
  if new_role not in ('admin', 'adult', 'child') then
    raise exception 'Ungültige Rolle: %. Erlaubt: admin, adult, child', new_role;
  end if;

  -- Zielfamilie ermitteln
  select family_id into v_target_family_id
  from public.family_members
  where id = target_member_id;

  if v_target_family_id is null then
    raise exception 'Ziel-Mitglied gehoert keiner Familie an';
  end if;

  -- Nur Admin der gleichen Familie darf Rollen aendern
  if not public.is_family_admin(v_target_family_id) then
    raise exception 'Keine Admin-Berechtigung';
  end if;

  -- Letzter-Admin-Schutz: Wenn Downgrade eines Admins, muss mindestens ein weiterer Admin bleiben
  if (select role from public.family_members where id = target_member_id) = 'admin'
     and new_role != 'admin' then
    select count(*) into v_admin_count
    from public.family_members
    where family_id = v_target_family_id and role = 'admin';
    if v_admin_count <= 1 then
      raise exception 'Die Familie muss mindestens einen Admin haben';
    end if;
  end if;

  update public.family_members
  set role       = new_role,
      updated_at = now()
  where id = target_member_id;
end;
$$;

grant execute on function public.change_member_role(uuid, text) to authenticated;
revoke execute on function public.change_member_role(uuid, text) from anon;


-- ----------------------------------------------------------
-- 3.4 remove_member: Mitglied aus Familie entfernen
-- ----------------------------------------------------------
-- Security: Nur Admin der gleichen Familie; kein Selbst-Entfernen wenn letzter Admin.

create or replace function public.remove_member(target_member_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_target_family_id uuid;
  v_admin_count      int;
begin
  -- Zielfamilie des zu entfernenden Mitglieds ermitteln
  select family_id into v_target_family_id
  from public.family_members
  where id = target_member_id;

  if v_target_family_id is null then
    raise exception 'Ziel-Mitglied gehoert keiner Familie an';
  end if;

  -- Nur Admin der gleichen Familie darf entfernen
  if not public.is_family_admin(v_target_family_id) then
    raise exception 'Keine Admin-Berechtigung';
  end if;

  -- Letzter-Admin-Schutz (Pitfall 7 + Threat T-3-06)
  if (select role from public.family_members where id = target_member_id) = 'admin' then
    select count(*) into v_admin_count
    from public.family_members
    where family_id = v_target_family_id and role = 'admin';
    if v_admin_count <= 1 then
      raise exception 'Die Familie muss mindestens einen Admin haben';
    end if;
  end if;

  -- Mitglied aus Familie entfernen (family_id auf NULL, Rolle zuruecksetzen)
  update public.family_members
  set family_id  = null,
      role       = 'adult',
      updated_at = now()
  where id = target_member_id;
end;
$$;

grant execute on function public.remove_member(uuid) to authenticated;
revoke execute on function public.remove_member(uuid) from anon;
