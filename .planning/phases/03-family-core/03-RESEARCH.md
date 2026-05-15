# Phase 3: Family Core — Research

**Researched:** 2026-05-15
**Domain:** Supabase PostgreSQL RPC + RLS, SwiftUI Onboarding-Navigation, FamilyService, Kinder-Profile
**Confidence:** HIGH

---

## Zusammenfassung

Phase 3 liefert die Familiengruppe als soziale Einheit der App. Ein frisch registrierter User hat `family_id = NULL` (per Phase 2 `handle_new_user`-Trigger) und landet auf `OnboardingPlaceholderView`. Dort kann er entweder eine Familie erstellen oder einer bestehenden Familie mit einem Einladungscode beitreten.

Die kritischen technischen Entscheidungen in dieser Phase:

**1. Atomic Family Creation via Postgres RPC.** Eine Postgres-Funktion (`create_family`) übernimmt sowohl das INSERT in `families` als auch das UPDATE des eigenen `family_members`-Eintrags auf `role = 'admin'` und `family_id = <neue_id>` in einer einzigen Transaktion. PL/pgSQL-Funktionen sind in Supabase automatisch atomar — kein manuelles `BEGIN/COMMIT` nötig. [VERIFIED: PostgreSQL-Dokumentation, supabase.com/docs/guides/database/functions]

**2. Token-basierter Invite-Fluss via `accept_invite` RPC.** Die `family_invites`-Tabelle aus Phase 1 hat bereits `token`, `expires_at`, `used_by`. Eine `SECURITY DEFINER`-Funktion `accept_invite(invite_token text)` validiert Token-Gültigkeit, prüft Ablaufdatum, setzt `family_id` und `role` des aufrufenden Users, markiert den Invite als benutzt — alles atomar. Der Token wird dem User als 6-8-stelliger Code (Base64-Substring) angezeigt; keine QR-Code-Komplexität nötig für v1. [VERIFIED: ARCHITECTURE.md, supabase.com/docs/guides/database/functions]

**3. Kinder-Profile ohne eigenen Auth-Account.** `KID-01` verlangt kein echtes Login für Kinder. Die `family_members`-Tabelle aus Phase 1 verwendet `id uuid primary key references auth.users(id)` — dieser Ansatz funktioniert NICHT für parent-managed Kinder ohne eigenes Gerät. **Lösung:** Einen separaten `child_profiles`-Tabellen-Ansatz implementieren, ODER die `family_members`-Tabelle durch eine `is_managed_child boolean`-Spalte erweitern und für managed Kinder eine Dummy-UUID (nicht mit `auth.users` verknüpft) verwenden. Der empfohlene Ansatz: eine neue `child_profiles`-Tabelle mit `family_id` und ohne `auth.users`-Referenz — deutlich sauberer für RLS. [ASSUMED: Keine offizielle Supabase-Empfehlung für diesen spezifischen Fall gefunden; basiert auf Datenbankarchitektur-Logik]

**4. Rollensystem und Privilege-Escalation-Prävention.** Die `family_members`-RLS-Policy für UPDATE muss `WITH CHECK` verwenden, um zu verhindern, dass ein User seine eigene `role`-Spalte ändert. Admin-Operationen (Rolle ändern, Mitglied entfernen) laufen über `SECURITY DEFINER`-RPCs. [VERIFIED: supabase.com/docs/guides/database/postgres/row-level-security]

**Primäre Empfehlung:** Atomic RPCs für alle Multi-Tabellen-Operationen (Family-Erstellung, Invite-Accept, Mitglied-Entfernen, Rollen-Änderung). SwiftUI `NavigationStack` mit `AppState.authenticated(hasFamily: false)` → `FamilyOnboardingView` → Subviews ohne Coordinator-Overhead. Kind-Profile als separate `child_profiles`-Tabelle (kein `auth.users`-FK).

---

<phase_requirements>
## Phase Requirements

| ID | Beschreibung | Research-Grundlage |
|----|-------------|-------------------|
| FAM-01 | Erster User einer Familie kann eine Familiengruppe erstellen und wird automatisch Admin | `create_family` RPC: INSERT families + UPDATE family_members atomar; `is_family_admin()` Funktion aus Phase 1 aktiviert sich danach |
| FAM-02 | Admin kann einen Einladungscode generieren; andere User können damit der Familiengruppe beitreten | `generate_invite` RPC (Admin only) erstellt `family_invites`-Row; `accept_invite` RPC validiert Token und setzt family_id |
| FAM-03 | Admin kann Familienmitglieder entfernen | `remove_member` RPC: setzt `family_id = NULL` und `role = 'adult'` im Mitglied, läuft via SECURITY DEFINER mit Admin-Check |
| FAM-04 | Admin kann die Rolle eines Mitglieds ändern (Admin / Erwachsen / Kind-vereinfacht) | `change_member_role` RPC mit Privilege-Escalation-Check; UPDATE-Policy mit WITH CHECK blockiert direkte Änderung |
| FAM-05 | Jedes Familienmitglied hat ein Profil mit Name, Avatar-Farbe und Rolle | `family_members.display_name`, `avatar_color`, `role` bereits in Phase 1 Schema; UPDATE eigenes Profil via `user manages own profile`-Policy |
| KID-01 | Kinder-Profile können von Eltern erstellt und verwaltet werden (kein eigenes Gerät nötig) | Neue `child_profiles`-Tabelle ohne auth.users-FK; wird in Phase 4 für Aktivitäts-Logging via LOG-04 benötigt |
| SETTINGS-03 | Familienmitglieder-Verwaltung: einladen (Code generieren), entfernen, Rolle ändern, Kinder-Modus umschalten | Aggregiert die anderen FAM-Requirements in einer MembersSettingsView; kein neues Backend |
</phase_requirements>

---

## Project Constraints (from CLAUDE.md)

| Direktive | Auswirkung auf Phase 3 |
|-----------|----------------------|
| RLS immer aktivieren | `child_profiles`-Tabelle braucht sofort RLS-Policies; kein ungeschütztes INSERT/SELECT |
| RLS nur mit echtem JWT testen | Alle neuen RPCs und Policies im Swift-Client testen (nicht Dashboard) |
| Score NIEMALS als mutabler Wert speichern | Gilt weiterhin; Phase 3 schreibt keine Scores |
| Supabase SDK NUR im Hauptapp-Target | FamilyService lebt im App Target; FamilyScoreKit nur für WidgetData-Struct |
| Realtime stirbt im iOS-Hintergrund | FamilyService subscribed Realtime erst in Phase 5; Phase 3 nur REST-Fetches |
| iOS 16.0 Minimum | `ObservableObject` + `@StateObject`; KEIN `@Observable` (iOS 17+) |
| Apple Health/Fitness Ästhetik | MemberListView: dunkler Hintergrund, große Avatar-Kreise, minimale Farben |
| 3 Taps Maximum | Einladungscode in max. 2 Taps sichtbar; Mitglied entfernen: Swipe + Confirm |

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Familie erstellen (atomic) | Supabase DB (RPC) | App Target (FamilyService) | INSERT + UPDATE atomar nötig; Postgres-Funktion ist die einzige sichere Option |
| Invite-Code generieren | Supabase DB (RPC / families-Policies) | App Target (FamilyService) | Admin-Only-Check via RLS; Token in DB generiert (nicht im Client) |
| Invite-Code einlösen | Supabase DB (RPC security definer) | App Target (FamilyService) | Token-Validierung + family_id-Update muss atomar und serverseitig sein |
| Mitglied entfernen | Supabase DB (RPC security definer) | App Target (FamilyService) | Admin-Check serverseitig; kein Trust auf Client-Assertion |
| Rolle ändern | Supabase DB (RPC security definer) | App Target (FamilyService) | Privilege-Escalation-Prävention serverseitig; WITH CHECK in RLS |
| Profil bearbeiten (eigenes) | App Target → Supabase REST | — | Direktes UPDATE via supabase-swift; bestehende Policy aus Phase 1 reicht |
| Kind-Profile verwalten | App Target (FamilyService) → Supabase REST | — | Eigene `child_profiles`-Tabelle mit family_id-basierter RLS |
| Onboarding-Navigation | App Target (SwiftUI) | — | RootView.authenticated(hasFamily: false) → FamilyOnboardingView |
| Mitgliederliste anzeigen | App Target (FamilyService + SwiftUI) | — | REST-Fetch auf family_members; kein Realtime in Phase 3 |
| AppState-Update nach Family-Join | App Target (AuthService) | — | AuthService.refreshFamilyStatus() nach erfolgreicher RPC |

---

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| supabase-swift | 2.46.0 | Datenbankabfragen via `.from()`, `.rpc()`, `.select()` | Bereits installiert (Phase 1); offizielles SDK |
| SwiftUI | iOS 16+ | FamilyOnboardingView, MemberListView, InviteSheet | Projektstandard |
| Foundation | iOS 16+ | UUID, Codable, URL | Apple Framework; kein Zusatzpaket |

### Supporting

| Library / Tool | Version | Purpose | When to Use |
|----------------|---------|---------|-------------|
| FamilyScoreKit | lokal | WidgetData erweitern um `avatarColor` | Falls Phase 3 neue WidgetData-Felder braucht |
| XCTest + MockFamilyService | Phase 2 aufgebaut | Unit-Tests für FamilyService-Logik | Wave 0 erweitern |

**Installation:** Keine neuen Pakete — Phase 3 nutzt ausschließlich was Phase 1 installiert hat.

---

## Architecture Patterns

### System Architecture Diagram

```
Onboarding Entry
  │
  ▼
AppState.authenticated(hasFamily: false)
  │
  ▼
FamilyOnboardingView
  ├─ "Familie erstellen" ────────────────────────────────────────────┐
  │                                                                   │
  │  CreateFamilyView                                                 │
  │    User gibt Familienname ein                                     │
  │    FamilyService.createFamily(name:)                             │
  │      └─► supabase.rpc("create_family", params: {name: ...})     │
  │              INSERT families + UPDATE family_members atomar       │
  │              returns family_id                                    │
  │    AuthService.refreshFamilyStatus()                             │
  │      └─► AppState = .authenticated(hasFamily: true)              │
  │                                                                   │
  └─ "Einladungscode eingeben" ──────────────────────────────────────┘
                                                                      │
     JoinFamilyView                                                   │
       User gibt 8-stelligen Code ein                                 │
       FamilyService.joinFamily(token:)                               │
         └─► supabase.rpc("accept_invite", params: {invite_token: ...})
                 Validiert Token-Gültigkeit + Ablaufdatum             │
                 UPDATE family_members (family_id, role)              │
                 UPDATE family_invites (used_by, used_at)             │
       AuthService.refreshFamilyStatus()                             │
         └─► AppState = .authenticated(hasFamily: true)              │
                                                                     ▼
MainTabView (Phase 4) ◄──────────────────────────────────────────────

Authenticated Family Member Flow:
─────────────────────────────────
MemberListView ◄── FamilyService.fetchMembers()
  │                  └─► supabase.from("family_members").select().eq("family_id")
  │
  ├─ Admin: InviteSheet ─► FamilyService.generateInvite()
  │                          └─► supabase.from("family_invites").insert()
  │                              returns: token (8-char Base64-Substring)
  │
  ├─ Admin: RolePicker ──► FamilyService.changeMemberRole(memberId:, role:)
  │                          └─► supabase.rpc("change_member_role", params: {...})
  │                              SECURITY DEFINER: Admin-Check + Privilege-Check
  │
  ├─ Admin: Mitglied entfernen ─► FamilyService.removeMember(memberId:)
  │                                └─► supabase.rpc("remove_member", params: {member_id: ...})
  │                                    SECURITY DEFINER: Admin-Check
  │
  └─ Admin: Kind hinzufügen ─► AddChildView
                                └─► FamilyService.createChildProfile(name:, avatarColor:)
                                    └─► supabase.from("child_profiles").insert()
```

### Empfohlene Projektstruktur (Phase 3 Ergänzungen)

```
FamilyScore/
├── Services/
│   ├── AuthService.swift          ← Phase 2; refreshFamilyStatus() hinzufügen
│   └── FamilyService.swift        ← NEU: ObservableObject; Familie + Einladungen
├── Models/
│   ├── AppState.swift             ← Phase 2; unveränderter Enum
│   ├── FamilyMember.swift         ← NEU: Codable Struct (id, display_name, avatar_color, role)
│   ├── Family.swift               ← NEU: Codable Struct (id, name, created_at)
│   ├── FamilyInvite.swift         ← NEU: Codable Struct (token, expires_at, used_by)
│   └── ChildProfile.swift         ← NEU: Codable Struct (id, family_id, display_name, avatar_color)
├── Views/
│   ├── RootView.swift             ← Phase 2; OnboardingPlaceholderView → FamilyOnboardingView
│   ├── Auth/                      ← Phase 2
│   └── Family/
│       ├── FamilyOnboardingView.swift  ← NEU: Tab-/Card-View: Erstellen | Beitreten
│       ├── CreateFamilyView.swift      ← NEU: Familienname-Feld + Erstellen-Button
│       ├── JoinFamilyView.swift        ← NEU: Code-Eingabefeld + Beitreten-Button
│       ├── MemberListView.swift        ← NEU: Mitgliederliste mit Admin-Aktionen
│       ├── InviteSheet.swift           ← NEU: Anzeige des generierten Invite-Codes
│       ├── RolePickerSheet.swift       ← NEU: Admin: Rolle eines Mitglieds ändern
│       └── AddChildView.swift          ← NEU: Kind-Profil anlegen (Name + Avatar-Farbe)
└── FamilyScoreApp.swift
```

### Pattern 1: Atomic Family Creation — RPC mit SECURITY DEFINER

**Was:** Eine Postgres-Funktion übernimmt sowohl den INSERT in `families` als auch das UPDATE des aufrufenden Users in `family_members` in einer einzigen Transaktion.

**Warum RPC statt zweier REST-Aufrufe:** Wenn der erste REST-Aufruf (INSERT families) gelingt, der zweite (UPDATE family_members.family_id) aber scheitert, ist der User ohne Familie und die `families`-Tabelle hat eine verwaiste Zeile. Ein RPC ist atomar.

**Wichtig:** PostgREST wrapped jeden `rpc()`-Aufruf automatisch in eine Postgres-Transaktion. PL/pgSQL-Funktionen laufen innerhalb dieser Transaktion — alle Statements sind atomar. [VERIFIED: PostgreSQL-Dokumentation + dev.to/voboda/gotcha-supabase-postgrest-rpc-with-transactions]

```sql
-- Migration: Phase 3 SQL
-- Neue Funktion: create_family
create or replace function public.create_family(family_name text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_family_id uuid;
begin
  -- Sicherheitscheck: User darf noch keiner Familie angehören
  if exists (
    select 1 from public.family_members
    where id = (select auth.uid())
      and family_id is not null
  ) then
    raise exception 'User gehört bereits einer Familie an';
  end if;

  -- Neue Familie anlegen
  insert into public.families (name, created_by)
  values (family_name, (select auth.uid()))
  returning id into v_family_id;

  -- User zum Admin der neuen Familie machen
  update public.family_members
  set family_id = v_family_id,
      role      = 'admin',
      updated_at = now()
  where id = (select auth.uid());

  return v_family_id;
end;
$$;
```

```swift
// Source: supabase.com/docs/reference/swift/rpc (adaptiert)
// FamilyService.swift

struct CreateFamilyParams: Encodable {
    let familyName: String
    enum CodingKeys: String, CodingKey { case familyName = "family_name" }
}

func createFamily(name: String) async throws -> UUID {
    let familyId: UUID = try await supabase
        .rpc("create_family", params: CreateFamilyParams(familyName: name))
        .execute()
        .value
    return familyId
}
```

### Pattern 2: Invite Accept — RPC mit Token-Validierung

**Was:** `accept_invite` RPC validiert Token-Gültigkeit serverseitig, verhindert Double-Use, und weist User der Familie zu.

**Warum SECURITY DEFINER:** Die RLS-Policy auf `family_invites` erlaubt nur Admins und Familienmitgliedern das Lesen. Ein Nutzer der noch keiner Familie angehört (`family_id = NULL`) kann den Invite-Token nicht direkt aus der Tabelle lesen. Die SECURITY DEFINER-Funktion überbrückt diese Lücke sicher, ohne die Tabelle vollständig zu öffnen.

```sql
-- Migration: Phase 3 SQL
create or replace function public.accept_invite(invite_token text)
returns uuid   -- gibt die family_id zurück
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
    raise exception 'User gehört bereits einer Familie an';
  end if;

  -- Token suchen und validieren
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

  -- Invite als benutzt markieren
  update public.family_invites
  set used_by = (select auth.uid()),
      used_at = now()
  where id = v_invite.id;

  return v_invite.family_id;
end;
$$;
```

```swift
// Source: supabase.com/docs/reference/swift/rpc (adaptiert)

struct AcceptInviteParams: Encodable {
    let inviteToken: String
    enum CodingKeys: String, CodingKey { case inviteToken = "invite_token" }
}

func joinFamily(token: String) async throws -> UUID {
    let familyId: UUID = try await supabase
        .rpc("accept_invite", params: AcceptInviteParams(inviteToken: token))
        .execute()
        .value
    return familyId
}
```

### Pattern 3: FamilyService — ObservableObject

**Was:** Zentraler Service für alle Familien-Operationen. Hält die Mitgliederliste und die aktuelle Familie als `@Published`-Properties.

**iOS 16-Kompatibilität:** Wie AuthService in Phase 2 — `ObservableObject` + `@Published` + `@StateObject`/`@EnvironmentObject`. KEIN `@Observable` (iOS 17+). [VERIFIED: CLAUDE.md "iOS 16.0 Minimum"]

```swift
// FamilyScore/Services/FamilyService.swift
// Target Membership: FamilyScore (App) ONLY

import Foundation
import Supabase

@MainActor
final class FamilyService: ObservableObject {

    @Published private(set) var currentFamily: Family?
    @Published private(set) var members: [FamilyMember] = []
    @Published private(set) var childProfiles: [ChildProfile] = []
    @Published var serviceError: String? = nil

    // MARK: - Familie laden

    func fetchFamily(familyId: UUID) async {
        do {
            let family: Family = try await supabase
                .from("families")
                .select()
                .eq("id", value: familyId.uuidString)
                .single()
                .execute()
                .value
            currentFamily = family
        } catch {
            serviceError = "Familie konnte nicht geladen werden."
        }
    }

    func fetchMembers(familyId: UUID) async {
        do {
            let fetched: [FamilyMember] = try await supabase
                .from("family_members")
                .select()
                .eq("family_id", value: familyId.uuidString)
                .order("created_at", ascending: true)
                .execute()
                .value
            members = fetched
        } catch {
            serviceError = "Mitglieder konnten nicht geladen werden."
        }
    }

    // MARK: - Familie erstellen/beitreten

    func createFamily(name: String) async throws -> UUID {
        struct Params: Encodable {
            let familyName: String
            enum CodingKeys: String, CodingKey { case familyName = "family_name" }
        }
        return try await supabase
            .rpc("create_family", params: Params(familyName: name))
            .execute()
            .value
    }

    func joinFamily(token: String) async throws -> UUID {
        struct Params: Encodable {
            let inviteToken: String
            enum CodingKeys: String, CodingKey { case inviteToken = "invite_token" }
        }
        return try await supabase
            .rpc("accept_invite", params: Params(inviteToken: token))
            .execute()
            .value
    }

    // MARK: - Einladung generieren (Admin only)

    func generateInvite(familyId: UUID, role: MemberRole) async throws -> String {
        // INSERT in family_invites; RLS-Policy erlaubt das nur Admins
        // Token wird von Postgres generiert (gen_random_bytes via Default)
        struct NewInvite: Encodable {
            let family_id: String
            let created_by: String
            let role: String
        }
        struct InviteResponse: Decodable { let token: String }

        guard let currentUserId = try? await supabase.auth.session.user.id else {
            throw FamilyServiceError.notAuthenticated
        }

        let response: InviteResponse = try await supabase
            .from("family_invites")
            .insert(NewInvite(
                family_id: familyId.uuidString,
                created_by: currentUserId.uuidString,
                role: role.rawValue
            ))
            .select("token")
            .single()
            .execute()
            .value

        // Token kürzen für UI-Anzeige (Base64 enthält Sonderzeichen)
        // Original: "abc123+def=" → UI zeigt ersten 8 alphanumerischen Zeichen
        return String(response.token.prefix(8))
    }
}

enum FamilyServiceError: Error, LocalizedError {
    case notAuthenticated
    case familyNotFound
    case invalidToken
    case alreadyInFamily
    case insufficientPermissions

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Bitte zuerst einloggen."
        case .familyNotFound: return "Familie nicht gefunden."
        case .invalidToken: return "Ungültiger oder abgelaufener Einladungscode."
        case .alreadyInFamily: return "Du bist bereits Mitglied einer Familie."
        case .insufficientPermissions: return "Keine Berechtigung für diese Aktion."
        }
    }
}

enum MemberRole: String, Codable, CaseIterable {
    case admin
    case adult
    case child
}
```

### Pattern 4: RLS — Privilege-Escalation-Prävention

**Was:** Die UPDATE-Policy auf `family_members` muss mit `WITH CHECK` verhindern, dass ein User seine eigene `role`-Spalte manipuliert.

**Warum:** Ohne `WITH CHECK` kann ein User ein direktes `UPDATE family_members SET role = 'admin' WHERE id = auth.uid()` absenden. Die `USING`-Klausel prüft nur ob der User die Zeile sehen/bearbeiten darf, nicht welche Werte er setzen darf.

```sql
-- Migration: Phase 3 — bestehende Phase 1 Policy "User verwaltet eigenes Profil" ersetzen

-- Alte Policy entfernen
drop policy if exists "User verwaltet eigenes Profil" on public.family_members;

-- Neue Policy: User kann display_name und avatar_color ändern, NICHT role oder family_id
create policy "User aktualisiert eigenes Profil (kein Rollen-Selbst-Upgrade)"
  on public.family_members for update to authenticated
  using ((select auth.uid()) = id)
  with check (
    (select auth.uid()) = id
    -- Rollenwert darf sich nicht ändern (kein Privilege Escalation)
    and role = (select m.role from public.family_members m where m.id = (select auth.uid()))
    -- family_id darf nicht selbst verändert werden
    and family_id = (select m.family_id from public.family_members m where m.id = (select auth.uid()))
  );
```

**Anmerkung zur SQL-Syntax:** Der `WITH CHECK`-Subquery auf die eigene Tabelle kann zu einem Logical-Read-Loop führen. Sicherer: die `change_member_role` und `remove_member` RPCs mit SECURITY DEFINER implementieren, während die direkte UPDATE-Policy auf safe Felder (display_name, avatar_color) beschränkt wird:

```sql
-- Empfohlene Alternative: spezifische Policy nur für safe Felder
-- Rollen und family_id werden AUSSCHLIESSLICH über RPCs verändert
-- Keine direkte UPDATE-Policy für role/family_id nötig

-- Admin-RPC für Rollen-Änderung
create or replace function public.change_member_role(target_member_id uuid, new_role text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Nur Admin der Zielfamilie darf Rollen ändern
  if not exists (
    select 1 from public.family_members caller
    join public.family_members target on target.id = target_member_id
    where caller.id = (select auth.uid())
      and caller.family_id = target.family_id
      and caller.role = 'admin'
  ) then
    raise exception 'Keine Admin-Berechtigung';
  end if;

  -- Sicherheitscheck: new_role ist gültig
  if new_role not in ('admin', 'adult', 'child') then
    raise exception 'Ungültige Rolle: %', new_role;
  end if;

  update public.family_members
  set role = new_role, updated_at = now()
  where id = target_member_id;
end;
$$;

-- Admin-RPC für Mitglied-Entfernung
create or replace function public.remove_member(target_member_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_target_family_id uuid;
begin
  -- Zielfamilie des zu entfernenden Mitglieds ermitteln
  select family_id into v_target_family_id
  from public.family_members
  where id = target_member_id;

  -- Nur Admin der gleichen Familie darf entfernen
  if not public.is_family_admin(v_target_family_id) then
    raise exception 'Keine Admin-Berechtigung';
  end if;

  -- Mitglied aus Familie entfernen (family_id auf NULL setzen, Rolle zurücksetzen)
  update public.family_members
  set family_id = null, role = 'adult', updated_at = now()
  where id = target_member_id;
end;
$$;
```

### Pattern 5: Kind-Profile — Separate Tabelle ohne auth.users-FK

**Was:** KID-01 braucht parent-managed Kinder-Profile ohne eigenes Device-Login. Die `family_members`-Tabelle hat `id uuid primary key references auth.users(id)` — das erfordert einen echten Auth-User. Stattdessen: eigene `child_profiles`-Tabelle.

**Warum separate Tabelle:**
- Kein Missbrauch des Auth-Systems mit Dummy-Accounts
- Klare Semantik: `family_members` = echte Users, `child_profiles` = managed profiles
- Einfachere RLS: jeder Family-Admin kann alle `child_profiles` seiner Familie sehen und verwalten
- Phase 4 (LOG-04) kann Aktivitäts-Einträge mit `child_profile_id` statt `user_id` erstellen

```sql
-- Migration: Phase 3 SQL — neue Tabelle

create table public.child_profiles (
  id            uuid primary key default gen_random_uuid(),
  family_id     uuid not null references public.families(id) on delete cascade,
  display_name  text not null,
  avatar_color  text not null default '#FF9500',  -- iOS Orange als Kind-Default
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

create policy "Admin verwaltet Kind-Profile"
  on public.child_profiles for all to authenticated
  using (public.is_family_admin(family_id));

create policy "Admin erstellt Kind-Profile"
  on public.child_profiles for insert to authenticated
  with check (public.is_family_admin(family_id));
```

**WICHTIG für Phase 4:** Die `activity_entries`-Tabelle aus Phase 1 hat `user_id uuid not null references auth.users(id)`. Für Kind-Profile muss Phase 4 entweder:
- Option A: `child_profile_id uuid references public.child_profiles(id)` als neue nullable Spalte hinzufügen (empfohlen — sauberste Lösung)
- Option B: Ein Proxy-User-Account pro Kind erstellen (nicht empfohlen — missbraucht Auth-System)

Phase 3 dokumentiert diesen zukünftigen Integrationspunkt, implementiert ihn aber nicht (ist Phase 4-Scope).

### Pattern 6: SwiftUI Onboarding-Navigation

**Was:** Nach Login mit `hasFamily: false` zeigt `RootView` die `FamilyOnboardingView`. Diese verwaltet den Übergang zu `CreateFamilyView` und `JoinFamilyView` via `NavigationStack`.

**Wichtig:** Keine Race Condition zwischen AuthService und FamilyService — `AuthService.refreshFamilyStatus()` updated `AppState` nachdem die RPC abgeschlossen ist. [ASSUMED: Pattern funktioniert, da `refreshFamilyStatus()` den gleichen `checkFamilyMembership()`-Flow wie Phase 2 verwendet]

```swift
// FamilyScore/Views/Family/FamilyOnboardingView.swift
// Ersetzt OnboardingPlaceholderView aus Phase 2

import SwiftUI

struct FamilyOnboardingView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var familyService: FamilyService

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 52))
                            .foregroundColor(.white)
                            .padding(.top, 60)
                        Text("Familiengruppe")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        Text("Erstelle eine neue Familie oder tritt einer bestehenden bei.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    // Aktions-Buttons
                    VStack(spacing: 16) {
                        NavigationLink(destination: CreateFamilyView()) {
                            Label("Neue Familie erstellen", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(Color.white)
                                .foregroundColor(.black)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 24)

                        NavigationLink(destination: JoinFamilyView()) {
                            Label("Mit Code beitreten", systemImage: "qrcode.viewfinder")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(Color.white.opacity(0.15))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 24)
                    }

                    Spacer()

                    Button("Ausloggen") {
                        Task { try? await authService.signOut() }
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarHidden(true)
        }
    }
}
```

### Pattern 7: AuthService.refreshFamilyStatus() — AppState nach RPC updaten

**Was:** Nachdem `createFamily` oder `joinFamily` erfolgreich war, muss `AppState` von `.authenticated(hasFamily: false)` zu `.authenticated(hasFamily: true)` wechseln. `AuthService` besitzt den `AppState`; `FamilyService` kann ihn nicht direkt ändern.

**Ansatz:** `AuthService` bekommt eine `refreshFamilyStatus()`-Methode, die `checkFamilyMembership()` erneut aufruft. `FamilyService` ruft diese nach erfolgreicher RPC auf, ODER `FamilyService` nimmt `AuthService` als Dependency.

**Empfehlung:** `FamilyService` gibt die neue `family_id` zurück. Die View ruft danach `authService.refreshFamilyStatus()` auf. So bleibt die Dependency-Richtung sauber (Services kommunizieren nicht direkt).

```swift
// Ergänzung zu AuthService.swift (Phase 2 Datei erweitern)

func refreshFamilyStatus() async {
    guard let userId = currentUser?.id else { return }
    let hasFamily = await checkFamilyMembership(userId: userId)
    appState = .authenticated(hasFamily: hasFamily)
}
```

### Anti-Patterns vermeiden

- **Anti-Pattern: Zwei REST-Aufrufe für Family-Creation** — INSERT families + UPDATE family_members als separate Swift-Aufrufe. Wenn der zweite Aufruf scheitert, ist der DB-State inkonsistent. Immer RPC verwenden.
- **Anti-Pattern: Token im Client generieren** — `invite_token` niemals im Swift-Client berechnen. DB-Default `encode(gen_random_bytes(12), 'base64')` ist kryptographisch sicher und server-seitig.
- **Anti-Pattern: Invite-Token via direktes SELECT lesen** — User ohne `family_id` unterliegt der RLS-Policy auf `family_invites`. Ein direktes `SELECT * FROM family_invites WHERE token = '...'` schlägt für unfamilied Users fehl. Nur die SECURITY DEFINER-RPC `accept_invite` umgeht dies sicher.
- **Anti-Pattern: Kind als Dummy-Auth-User** — `auth.users` mit "kind@familie.local" E-Mails anlegen. Missbraucht das Auth-System, verursacht Probleme bei E-Mail-Validierung, zählt gegen Auth-Quota. Stattdessen `child_profiles`-Tabelle verwenden.
- **Anti-Pattern: Admin-Check in iOS-Client** — `if currentUser.role == "admin"` im Swift-Code und DANN eine Operation ausführen. Der Server macht den Check nicht erneut. Immer serverseitiger Check via SECURITY DEFINER-RPC.
- **Anti-Pattern: NavigationStack Race Condition** — `navigationPath.append(destination)` während laufender Animation. PITFALLS.md dokumentiert: `Task { @MainActor in ... }` mit `await Task.yield()` vor jedem programmatischen NavigationPath-Push.
- **Anti-Pattern: `@Observable` für FamilyService** — iOS 16 Minimum. Immer `ObservableObject` + `@Published`. [VERIFIED: CLAUDE.md "iOS 16.0 Minimum"]

---

## Don't Hand-Roll

| Problem | Nicht bauen | Stattdessen | Warum |
|---------|-------------|-------------|-------|
| Atomare Multi-Tabellen-Operationen | Sequenzielle REST-Aufrufe aus Swift | Postgres-RPC (`create_family`, `accept_invite`) | Automatic Postgres transaction wrapping; kein Partial-Write-State |
| Token-Generierung | `UUID().uuidString.prefix(8)` im Swift-Client | `gen_random_bytes(12)` in DB-Default | Kryptographisch sicher, server-seitig, nicht vorhersagbar |
| Token-Validierung | `expires_at < Date()` im Swift-Client | Serverseitiger Check in `accept_invite` RPC | Race Conditions; Client-Clock kann falsch gehen (PITFALLS.md: Device Clock Skew) |
| Admin-Prüfung | `currentMember.role == "admin"` in Swift | SECURITY DEFINER RPCs mit serverseitigem Admin-Check | Client-Assertion wird nie validiert ohne serverseitigen Check |
| Invite-Code Display-Format | Base64 direkt anzeigen | `.prefix(8)` des DB-Tokens als Code | Base64 enthält `+`, `/`, `=` — schlecht für manuelles Abtippen; 8 alphanumerische Zeichen sind ausreichend eindeutig |

**Key insight:** Multi-Tabellen-Operationen, Token-Validierung und Berechtigungsprüfungen gehören ausnahmslos in SECURITY DEFINER Postgres-Funktionen. Der Swift-Client ist UI-Layer, kein Sicherheits-Layer.

---

## Common Pitfalls

### Pitfall 1: invite_token RLS-Block für unfamilied Users

**What goes wrong:** Neuer User gibt einen Einladungscode ein. `FamilyService.joinFamily(token:)` versucht `supabase.from("family_invites").select().eq("token", value: token)` — kommt leeres Ergebnis zurück. Kein Fehler, aber auch keine Familie.

**Why it happens:** Die RLS-Policy auf `family_invites` aus Phase 1 erlaubt nur Familienmitgliedern und dem `created_by`-User das Lesen. Ein User ohne `family_id` ist kein Familienmitglied — Policy gibt false zurück.

**How to avoid:** `accept_invite` als SECURITY DEFINER RPC — nicht direktes SELECT. Die Funktion läuft mit Creator-Rechten und umgeht RLS für das Token-Lookup.

**Warning signs:** `joinFamily()` gibt leeres Ergebnis statt Fehler zurück; User landet weiter auf FamilyOnboardingView.

---

### Pitfall 2: family_members UPDATE Policy und WITH CHECK Subquery Loop

**What goes wrong:** `WITH CHECK`-Policy die auf dieselbe Tabelle zurückverweist (`SELECT role FROM family_members WHERE id = auth.uid()`) kann bei manchen Postgres-Versionen zu einem Policy-Re-Evaluation-Loop führen oder unerwartet fehlschlagen.

**Why it happens:** RLS-Policies auf `family_members` werden für JEDE Row-Evaluation ausgeführt. Ein Subquery der dieselbe Tabelle liest, kann zu Rekursion führen.

**How to avoid:** Rollen-Änderungen AUSSCHLIESSLICH über SECURITY DEFINER RPCs (`change_member_role`) abwickeln. Die direkte UPDATE-Policy auf `family_members` auf safe Felder beschränken: `display_name`, `avatar_color`. Die `role`- und `family_id`-Felder nicht über direkte UPDATE zugänglich machen.

**Warning signs:** `403` oder `500` beim direkten UPDATE-Aufruf auf `family_members`; Loop-artige Logs im Supabase-Dashboard.

---

### Pitfall 3: AppState bleibt hasFamily: false nach erfolgreicher RPC

**What goes wrong:** `createFamily()` oder `joinFamily()` kehrt mit einer `family_id` zurück. Die App zeigt aber weiterhin `FamilyOnboardingView`. `MainTabView` erscheint nicht.

**Why it happens:** `FamilyService.createFamily()` updated die DB, aber `AuthService.appState` hört auf `authStateChanges` — und `authStateChanges` feuert KEIN neues Event wenn sich `family_members.family_id` ändert (nur Auth-Events). `appState` ist weiterhin `.authenticated(hasFamily: false)`.

**How to avoid:** Nach jeder erfolgreichen Familie-Operation `authService.refreshFamilyStatus()` aufrufen. Diese Methode führt `checkFamilyMembership()` erneut aus und setzt `appState = .authenticated(hasFamily: true)`.

**Warning signs:** Nach "Familie erstellen" bleibt die App auf `FamilyOnboardingView`.

---

### Pitfall 4: Invite-Token Ablaufdatum — client-seitig nicht prüfen

**What goes wrong:** Swift-Code prüft `invite.expiresAt < Date()` bevor `accept_invite` aufgerufen wird. Server-Uhr und Client-Uhr weichen ab (PITFALLS.md: Device Clock Skew). Token ist laut Client noch gültig, aber laut Server abgelaufen.

**How to avoid:** Ablaufdatum-Prüfung NUR in der `accept_invite` RPC mit `expires_at > now()`. Client zeigt keinen "abgelaufen"-Status ohne Server-Bestätigung.

---

### Pitfall 5: Familie ohne Kategorie-Config

**What goes wrong:** Familie wird erstellt, aber keine Standard-Kategorien in `category_config` angelegt. Phase 4 (Activity Logging) kann keine Kategorie auswählen.

**Why it happens:** Phase 1 Schema hat `category_config` mit `family_id NOT NULL` — ohne einen Insert sind keine Kategorien vorhanden.

**How to avoid:** `create_family` RPC um Standard-Kategorie-Seeding erweitern:

```sql
-- Innerhalb der create_family Funktion, nach dem INSERT in families:
insert into public.category_config (family_id, name, icon, color, point_weight, sort_order)
values
  (v_family_id, 'Haushalt',       'house.fill',      '#FF3B30', 1.5, 0),
  (v_family_id, 'Hobby/Freizeit', 'gamecontroller.fill', '#34C759', 1.0, 1),
  (v_family_id, 'Besorgungen',    'bag.fill',        '#FF9500', 1.2, 2),
  (v_family_id, 'Arbeit/Schule',  'book.fill',       '#007AFF', 1.8, 3);
```

**Warning signs:** Phase 4 zeigt leere Kategorie-Liste; activity_entries Insert schlägt wegen fehlender category_id fehl.

---

### Pitfall 6: child_profiles ohne family_id-Index

**What goes wrong:** `FamilyService.fetchChildProfiles(familyId:)` ist langsam bei großen Familien-Datenmengen.

**How to avoid:** Index `child_profiles_family_id` wurde bereits im Pattern 5 SQL definiert. Sicherstellen dass dieser in der Migration enthalten ist.

---

### Pitfall 7: Admin entfernt sich selbst

**What goes wrong:** Letzter Admin einer Familie entfernt sich selbst. Familie hat nun keinen Admin mehr — kein User kann administrative Aktionen ausführen.

**How to avoid:** In `remove_member` RPC prüfen, ob das Ziel-Mitglied der letzte Admin ist:

```sql
-- In remove_member, vor dem UPDATE:
if (select role from public.family_members where id = target_member_id) = 'admin' then
  if (select count(*) from public.family_members
      where family_id = v_target_family_id and role = 'admin') <= 1 then
    raise exception 'Die Familie muss mindestens einen Admin haben';
  end if;
end if;
```

**Warning signs:** Familie ohne Admin in der Datenbank; kein User kann Einladungen generieren oder Rollen verwalten.

---

## Code Examples

### Mitglied-Liste laden (verified API-Pattern)

```swift
// Source: supabase.com/docs/reference/swift (adaptiert für family_members)
struct FamilyMember: Codable, Identifiable {
    let id: UUID
    let family_id: UUID?
    let display_name: String
    let avatar_color: String
    let role: String
    let created_at: Date
}

let members: [FamilyMember] = try await supabase
    .from("family_members")
    .select()
    .eq("family_id", value: familyId.uuidString)
    .order("created_at", ascending: true)
    .execute()
    .value
```

### Eigenes Profil updaten (display_name, avatar_color)

```swift
// Source: supabase.com/docs/reference/swift (adaptiert)
struct ProfileUpdate: Encodable {
    let display_name: String
    let avatar_color: String
    let updated_at: Date
}

try await supabase
    .from("family_members")
    .update(ProfileUpdate(
        display_name: newName,
        avatar_color: newColor,
        updated_at: Date()
    ))
    .eq("id", value: currentUserId.uuidString)
    .execute()
```

### Einladung generieren und Token anzeigen

```swift
// Admin generiert Invite und zeigt Code in InviteSheet an
// Source: supabase-swift insert + select returning

struct NewInvite: Encodable {
    let family_id: String
    let created_by: String
    let role: String
}
struct InviteToken: Decodable { let token: String }

let result: InviteToken = try await supabase
    .from("family_invites")
    .insert(NewInvite(family_id: fid, created_by: uid, role: "adult"))
    .select("token")
    .single()
    .execute()
    .value

// Für UI: Base64-Token kürzen (erste 8 Zeichen, alphanumerisch)
let displayCode = result.token
    .filter { $0.isLetter || $0.isNumber }
    .prefix(8)
    .uppercased()
```

---

## State of the Art

| Alte Methode | Aktuelle Methode | Geändert seit | Bedeutung |
|--------------|-----------------|--------------|-----------|
| Separate REST-Calls für Multi-Table-Ops | Postgres RPC (PL/pgSQL) | Always best practice | Atomic; kein Partial-Write |
| `ObservableObject` (allgemein) | `ObservableObject` (iOS 16) / `@Observable` (iOS 17+) | iOS 17 | iOS 16-Minimum erzwingt ObservableObject |
| Child-Account via separatem auth.users-User | `child_profiles`-Tabelle ohne auth.users-FK | Best practice seit immer | Kein Auth-System-Missbrauch; saubere RLS |
| Token als UUID | `gen_random_bytes(12)` Base64 | Best practice | Kryptographisch sicher; URL-safe Base64 |
| RLS check mit auth.uid() direkt in Policy | `(select auth.uid())` in Policy | Postgres optimization | Einmal pro Query statt einmal pro Row evaluiert |

---

## Runtime State Inventory

> Phase 3 ist keine Rename/Refactor-Phase. Dieser Abschnitt ist nicht anwendbar.

Phase 3 erstellt neue Daten (Familien, Invites, Kind-Profile). Es gibt keinen Runtime-State der umbenannt werden muss.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `child_profiles`-Tabelle ohne `auth.users`-FK ist der richtige Ansatz für KID-01 (keine offizielle Supabase-Empfehlung gefunden) | Pattern 5 | Mittel: Falls Phase 4 activity_entries mit child_profile_id verknüpft werden sollen, braucht es eine zusätzliche nullable Spalte in activity_entries. Das ist bereits als Phase 4-Integrationspunkt dokumentiert. |
| A2 | Der kürzeste Base64-Substring (8 Zeichen) als Invite-Code ist ausreichend eindeutig für eine Familie | Pattern 2, Code Example | Niedrig: Bei sehr vielen gleichzeitigen Invites könnte Kollision entstehen. Für eine Familien-App (< 10 gleichzeitige offene Invites) ist Kollisionsrisiko vernachlässigbar. Bei Bedarf auf 12 Zeichen erhöhen. |
| A3 | `refreshFamilyStatus()` in AuthService ist die sauberste Lösung um AppState nach Family-Join zu updaten (Alternative: Combine/Notification zwischen Services) | Pattern 7 | Niedrig: Funktioniert korrekt; kein Race Condition-Risiko da `checkFamilyMembership()` direkt nach erfolgreicher RPC aufgerufen wird. |
| A4 | Die bestehende RLS-Policy "Admin verwaltet Familienmitglieder" aus Phase 1 (`for all to authenticated using public.is_family_admin(family_id)`) deckt bereits Admin-only Updates auf `role` und `family_id` ab — die neue `WITH CHECK`-Policy ist damit eine Verbesserung, kein Breaking Change | Pattern 4 | Mittel: Falls Phase 1 Policy breiter war als erwartet, könnte die neue Policy User-Flows sperren die vorher funktionierten. Vollständige Policy-Liste in Migration testen. |
| A5 | Die `family_invites`-Policy aus Phase 1 ("Admin verwaltet Einladungen" + "Familienmitglieder und Ersteller können Einladungen lesen") erlaubt dem Admin das INSERT einer neuen Einladung korrekt — kein `generate_invite` RPC nötig, direktes INSERT reicht | Pattern 3 | Niedrig: Policy `for all to authenticated using public.is_family_admin(family_id)` deckt INSERT ab. Muss mit echtem JWT getestet werden (RLS Dashboard-Test bypassed RLS). |

---

## Open Questions

1. **activity_entries.user_id für Kind-Profile in Phase 4**
   - Was wir wissen: `activity_entries.user_id` ist `NOT NULL references auth.users(id)`. Kind-Profile haben keine auth.users-Zeile.
   - Was unklar ist: Phase 4 muss `activity_entries` um `child_profile_id uuid nullable references child_profiles(id)` erweitern. Entweder `user_id` wird nullable (Breaking Change) oder `child_profile_id` kommt als optionale Alternative.
   - Empfehlung: Jetzt in Phase 3 einen `TODO: Phase 4 Integrationspunkt`-Kommentar in die Phase-3-SQL-Migration aufnehmen. Entscheidung in Phase 4 Research treffen.

2. **Maximale Anzahl Admins pro Familie**
   - Was wir wissen: Schema hat keine Beschränkung. `is_family_admin()` gibt `true` für beliebig viele Admins zurück.
   - Was unklar ist: Ob ein User den letzten anderen Admin degradieren kann (leaving keine Admins) — `change_member_role` RPC braucht einen entsprechenden Check.
   - Empfehlung: In `change_member_role` prüfen, ob das Downgrade des Ziels zu "keine Admins mehr" führen würde.

3. **Invite-Code Länge und Charset**
   - Was wir wissen: `gen_random_bytes(12)` mit Base64 = 16 Zeichen inkl. `+`, `/`, `=`.
   - Was unklar ist: Ob Sonderzeichen bei Abtippen frustrieren. Alternative: `.prefix(8)` + `.filter { isLetter || isNumber }` + `.uppercased()` — gibt 8 alphanumerische Großbuchstaben.
   - Empfehlung: 8 alphanumerische Großbuchstaben als Display-Code. Original-Token bleibt in DB für RPC-Aufruf (wird nicht angezeigt).

---

## Environment Availability

> Phase 3 hat keine neuen externen Abhängigkeiten.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Supabase-Projekt (live) | Alle FAM-Requirements | Ja (Phase 1 + Phase 2) | Free Tier | — |
| PostgreSQL DDL-Zugriff | SQL-Migration Phase 3 | Ja (Supabase CLI + Dashboard) | — | — |
| Xcode 16+ auf Mac | Build + Test | Ja (Phase 1 Voraussetzung) | 16+ | — |
| iOS Gerät (physisch) | Invite-Fluss-Test (2 Geräte für echten Cross-Device-Test) | Optional für Simulator-Test | iOS 16+ | Simulator mit 2 App-Instanzen |

**Missing dependencies with no fallback:** keine.

---

## Validation Architecture

> `nyquist_validation: true` in config.json — diese Sektion ist Pflicht.

### Test-Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (Phase 2 Wave 0 hat FamilyScoreTests-Target erstellt) |
| Config file | `FamilyScore.xcodeproj` → Test-Target `FamilyScoreTests` (bereits vorhanden) |
| Quick run command | `xcodebuild build -scheme FamilyScore -destination "platform=iOS Simulator,name=iPhone 16" -quiet` |
| Full suite command | `xcodebuild test -scheme FamilyScore -destination "platform=iOS Simulator,name=iPhone 16"` |

### Phase Requirements → Test-Map

| Req ID | Verhalten | Test-Typ | Automatisierbar | Datei |
|--------|-----------|----------|-----------------|-------|
| FAM-01 | createFamily() setzt appState auf hasFamily: true | Unit (Mock) | Ja | `FamilyScoreTests/FamilyServiceTests.swift` |
| FAM-01 | createFamily() während User schon Familie hat → Fehler | Unit (Mock) | Ja | `FamilyScoreTests/FamilyServiceTests.swift` |
| FAM-02 | generateInvite() gibt non-empty token zurück | Integration (Simulator) | Ja | `FamilyScoreTests/FamilyServiceTests.swift` |
| FAM-02 | joinFamily() mit gültigem Token → family_id gesetzt | Integration (Simulator) | Ja | `FamilyScoreTests/FamilyServiceTests.swift` |
| FAM-02 | joinFamily() mit abgelaufenem Token → Fehler | Integration (Simulator) | Ja | `FamilyScoreTests/FamilyServiceTests.swift` |
| FAM-03 | removeMember() von Admin → Mitglied hat family_id=null | Integration (2 Test-Accounts) | Ja (Simulator) | `FamilyScoreTests/FamilyServiceTests.swift` |
| FAM-04 | changeMemberRole() von Admin → Rolle geändert | Integration | Ja | `FamilyScoreTests/FamilyServiceTests.swift` |
| FAM-04 | User ändert eigene Rolle direkt → RLS blockiert | Integration (Simulator) | Ja | `FamilyScoreTests/FamilyServiceTests.swift` |
| FAM-05 | updateProfile() ändert display_name + avatar_color | Integration | Ja | `FamilyScoreTests/FamilyServiceTests.swift` |
| KID-01 | createChildProfile() erstellt Zeile in child_profiles | Integration | Ja | `FamilyScoreTests/FamilyServiceTests.swift` |
| SETTINGS-03 | Admin sieht "Mitglied entfernen" Option; Nicht-Admin sieht sie nicht | Manuell auf Gerät | Nein — UI-Validierung | Manuell |

### Wave 0 Gaps

- [ ] `FamilyScoreTests/FamilyServiceTests.swift` — Unit + Integration Tests für FAM-01 bis KID-01
- [ ] `FamilyScoreTests/Mocks/MockFamilyService.swift` — Mock-Implementierung für Preview-Injektion

*(FamilyScoreTests-Target selbst ist bereits aus Phase 2 Wave 0 vorhanden)*

### Sampling Rate

- **Per Task Commit:** `xcodebuild build -scheme FamilyScore -destination "platform=iOS Simulator,name=iPhone 16" -quiet`
- **Per Wave Merge:** `xcodebuild test -scheme FamilyScore -destination "platform=iOS Simulator,name=iPhone 16"`
- **Phase Gate:** Invite-Fluss auf zwei echten Geräten manuell verifiziert vor `/gsd-verify-work`

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | Nein (Phase 2 erledigt) | — |
| V3 Session Management | Nein (Phase 2 erledigt) | — |
| V4 Access Control | **Ja** | RLS SECURITY DEFINER RPCs; Admin-Check serverseitig |
| V5 Input Validation | **Ja** | Familienname: Länge-Check in DB-Funktion; Token-Format: passthrough an Postgres |
| V6 Cryptography | **Ja** | Invite-Token: `gen_random_bytes(12)` in DB — nie im Client generiert |

### Known Threat Patterns für diesen Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| User setzt eigene Rolle auf 'admin' via direktem UPDATE | Elevation of Privilege | `WITH CHECK`-Policy auf `family_members` blockiert role-Änderung; `change_member_role` RPC hat Admin-Check |
| Replay eines bereits verwendeten Invite-Tokens | Spoofing | `accept_invite` RPC prüft `used_by is null` — Token ist single-use |
| Erschöpfung aktiver Invites (Token-Flooding) | Denial of Service | Admin-Only INSERT auf `family_invites` via RLS; nur Admins können Invites generieren |
| Cross-Family Data Access via `family_id`-Manipulation | Information Disclosure | `is_family_member()` + `is_family_admin()` SECURITY DEFINER Funktionen aus Phase 1 greifen auf allen Tabellen |
| Kind-Profil-Manipulation durch Nicht-Admin | Tampering | `child_profiles` RLS: "Admin verwaltet Kind-Profile" — nur Admins können erstellen/ändern/löschen |
| Letzter Admin entfernt sich selbst | Denial of Service | `remove_member` RPC prüft: mindestens 1 Admin muss verbleiben |
| Token brute-force (8 Zeichen Display-Code) | Spoofing | Display-Code ist nur ein UI-Alias; tatsächlicher Token ist 16 Base64-Zeichen = 96 Bits Entropie; `accept_invite` RPC könnte rate-limiting bekommen (Phase 6) |

---

## Sources

### Primary (HIGH confidence)
- Phase 1 `20260515_initial_schema.sql` — vollständige Schema-Übersicht: `family_members`, `family_invites`, `families`, `category_config`; RLS-Policies; `is_family_member()`, `is_family_admin()`
- Phase 2 `02-RESEARCH.md` — `AuthService`, `AppState`-Enum, `checkFamilyMembership()` Pattern; bestätigt iOS 16 ObservableObject-Pflicht
- [supabase.com/docs/reference/swift/rpc](https://supabase.com/docs/reference/swift/rpc) — `.rpc()` Swift API verifiziert
- [supabase.com/docs/guides/database/postgres/row-level-security](https://supabase.com/docs/guides/database/postgres/row-level-security) — `WITH CHECK`-Pattern für UPDATE-Policies verifiziert
- [Context7: /supabase/supabase-swift — insert, select, rpc](https://context7.com/supabase/supabase-swift) — Swift API Code-Examples verifiziert
- `.planning/research/ARCHITECTURE.md` — `accept_invite` RPC Pattern, child account design decisions, atomic family creation flow
- `.planning/research/PITFALLS.md` — Device Clock Skew, Realtime Hintergrundlimits, RLS Cross-Family Exposure, NavigationStack Race Condition
- [PostgreSQL-Dokumentation — Transactions](https://www.postgresql.org/docs/current/tutorial-transactions.html) — PL/pgSQL Atomizität bestätigt

### Secondary (MEDIUM confidence)
- [dev.to/voboda — Supabase PostgREST RPC with Transactions](https://dev.to/voboda/gotcha-supabase-postgrest-rpc-with-transactions-45a7) — PostgREST wrapped rpc() in Transaktion bestätigt
- [makerkit.dev — Supabase RLS Best Practices](https://makerkit.dev/blog/tutorials/supabase-rls-best-practices) — Privilege-Escalation-Prävention Pattern
- [github.com/orgs/supabase/discussions/526](https://github.com/orgs/supabase/discussions/526) — Client-side transactions nicht empfohlen; RPC-first Ansatz bestätigt

### Tertiary (LOW confidence)
- WebSearch zu SwiftUI NavigationStack Onboarding Patterns 2025 — Community-Tutorials; Pattern basiert auf verifizierten Apple-Docs (NavigationStack iOS 16+)

---

## Metadata

**Confidence breakdown:**
- Family Creation RPC Pattern: HIGH — Postgres-Transaktions-Verhalten aus offizieller Dokumentation; ARCHITECTURE.md bestätigt Pattern
- accept_invite RPC: HIGH — SQL aus ARCHITECTURE.md direkt übernommen und erweitert; supabase-swift `.rpc()` API verifiziert
- Kind-Profile (child_profiles Tabelle): MEDIUM — Ansatz logisch und sauber; keine offizielle Supabase-Empfehlung spezifisch für diesen Case (A1 im Assumptions Log)
- RLS WITH CHECK Privilege Protection: HIGH — offizielle Supabase RLS-Doku verifiziert
- SwiftUI Navigation: MEDIUM — NavigationStack iOS 16+ aus Apple-Doku; Community-Patterns bestätigen Coordinator-Ansatz
- Kategorie-Seeding in create_family: HIGH — ARCHITECTURE.md erwähnt Seeding; Phase 4 wäre blockiert ohne es

**Research date:** 2026-05-15
**Valid until:** 2026-06-15 (30 Tage; supabase-swift API ist stabil; Postgres-RLS ändert sich nicht)
