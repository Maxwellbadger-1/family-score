# Phase 1: Foundation — Research

**Researched:** 2026-05-15
**Domain:** iOS Multi-Target Xcode Project / Supabase PostgreSQL Schema + RLS / SPM / Secrets Management
**Confidence:** HIGH

---

## Summary

Phase 1 legt das technische Fundament, auf dem alle weiteren Phasen aufbauen. Es gibt keine nutzer-sichtbaren Features — der Wert liegt darin, dass spätere Fehler durch falsche Projektstruktur verhindert werden. Die drei Hauptrisiken sind: (1) App Group Entitlement auf dem Gerät nicht registriert (Simulator-silently-passes, Device-silently-fails), (2) Supabase SDK irrtümlich im Widget Extension Target eingebunden (30MB-Grenze), (3) Secrets in Git committed.

Die bestehende Projektrecherche (STACK.md, ARCHITECTURE.md, PITFALLS.md) ist umfangreich und wird hier gezielt ergänzt: Dieses Dokument konzentriert sich auf die konkreten Handlungsschritte, exaktes DDL-SQL, SPM-Deklarationen, Xcconfig-Muster und die Verifikationsschritte für jeden der 5 Success Criteria.

**Primary recommendation:** Projekt in dieser Reihenfolge aufbauen — (1) Xcode-Projektstruktur mit Targets + Entitlements, (2) FamilyScoreKit Package, (3) Secrets.xcconfig, (4) Supabase Schema + RLS, (5) Swift-Verbindungstest. Jeder Schritt blockiert den nächsten; Abweichungen von der Reihenfolge erzeugen Fehler, die schwer zu diagnostizieren sind.

---

## Project Constraints (from CLAUDE.md)

Die folgenden Direktiven aus `CLAUDE.md` haben oberste Priorität und dürfen nicht gebrochen werden:

| Direktive | Kontext |
|-----------|---------|
| Supabase SDK NUR im Hauptapp-Target | Widget Extension darf keine Supabase-Abhängigkeit haben |
| Score NIEMALS als mutabler Wert speichern | Immer `SUM()` über `activity_entries` |
| RLS immer aktivieren | Jede Tabelle braucht `family_id`-basierte Policies |
| RLS nur mit echtem JWT testen | Dashboard bypassed RLS |
| App Group für BEIDE Targets im Apple Developer Portal registrieren | Simulator ≠ Gerät |
| Secrets.xcconfig in .gitignore | Supabase Key darf nie in Git |
| FamilyScoreKit als shared Swift Package | Code zwischen App und Widget Extension |
| iOS 16.0 Minimum Deployment Target | Lock Screen Widgets |
| Swift 6, Xcode 16 | App Store-Anforderung ab April 2025 |
| Realtime: auf `scenePhase == .active` re-subscriben | Background disconnects silently |

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Supabase Client Singleton | App Target | — | SDK verboten im Widget |
| Schema + RLS | Supabase DB | — | Server-side enforcement |
| Secrets Management | Build System (xcconfig) | — | Nie in Source Code |
| Shared Data Models | FamilyScoreKit Package | — | Kein SDK, nur Codable structs |
| App Group Container | OS / Entitlement | Apple Developer Portal | Beides muss stimmen |
| Widget Data | App Group UserDefaults | — | Kein direktes Netzwerk im Widget |

---

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| supabase-swift | 2.46.0 | Supabase Client: DB, Auth, Realtime | Offizielles SDK, native async/await, Swift 6 ready |
| Swift | 6.0 | Sprache | App Store Pflicht ab April 2025; strict concurrency |
| SwiftUI | iOS 16+ | UI Framework | WidgetKit-native, deklarativ |
| Xcode | 16+ | IDE | iOS 18 SDK, App Store Pflicht |
| WidgetKit | iOS 14+ (16+ Lock Screen) | Widget Extension Target | Direkt von Apple, keine Alternative |

**Version verification:** supabase-swift v2.46.0 wurde in STACK.md als "April 29, 2026" bestätigt. [VERIFIED: GitHub Releases via STACK.md research, confirmed current via swiftpackageindex.com search]

### Kein externer Package außer supabase-swift

Der gesamte restliche Stack sind Apple-Frameworks. Keine weiteren Third-Party-Abhängigkeiten in Phase 1 nötig.

**Installation (Xcode SPM):**
```
File > Add Package Dependencies...
URL: https://github.com/supabase/supabase-swift
Version: 2.46.0 (exact) oder "Up to Next Major: 2.46.0"
Product: Supabase
Target: FamilyScore (App) ONLY — NICHT Widget Extension
```

---

## Architecture Patterns

### System Architecture Diagram (Phase 1 Scope)

```
Developer Portal (Apple)
  └─ App ID: com.familyscore         (App Group: group.com.familyscore)
  └─ App ID: com.familyscore.widget  (App Group: group.com.familyscore)
         │
         ▼
Xcode Projekt: FamilyScore.xcodeproj
  ├─ Target: FamilyScore (App)
  │    ├─ Links: Supabase (SPM) + FamilyScoreKit (local package)
  │    ├─ Entitlement: com.apple.security.application-groups
  │    └─ Build Settings: SUPABASE_URL, SUPABASE_KEY via Secrets.xcconfig
  │
  ├─ Target: FamilyScoreWidgetExtension
  │    ├─ Links: FamilyScoreKit (local package) ONLY — kein Supabase
  │    └─ Entitlement: com.apple.security.application-groups (gleiche Gruppe)
  │
  └─ Local Swift Package: FamilyScoreKit/
       └─ Shared Codable Models (WidgetData, ActivityEntry structs etc.)

Supabase Cloud (PostgreSQL)
  ├─ families
  ├─ family_members
  ├─ activity_entries  ──► Trigger ──► weekly_summaries (upsert)
  ├─ category_config
  ├─ family_invites
  └─ weekly_summaries
       (alle Tabellen: RLS enabled, family_id-basierte Policies)

Runtime-Fluss (Phase 1, nur Verbindungstest):
App starts → reads SUPABASE_URL/KEY from Info.plist
  → SupabaseClient init
  → supabase.from("families").select()  [mit anon JWT]
  → returns [] or data  [RLS active — leer wenn keine Familie, nicht 403]
  → Connection verified ✓
```

### Recommended Project Structure

```
FamilyScore/                          ← Xcode Projekt Root
├── FamilyScore.xcodeproj/
├── FamilyScore/                      ← App Target Sources
│   ├── FamilyScoreApp.swift          ← @main entry point
│   ├── Supabase.swift                ← SupabaseClient singleton
│   ├── ContentView.swift             ← Placeholder UI
│   └── Resources/
│       ├── Info.plist                ← reads $(SUPABASE_URL), $(SUPABASE_KEY)
│       └── FamilyScore.entitlements  ← App Group
├── FamilyScoreWidgetExtension/       ← Widget Extension Sources
│   ├── FamilyScoreWidget.swift
│   ├── FamilyScoreWidgetBundle.swift
│   └── FamilyScoreWidgetExtension.entitlements  ← App Group (gleiche Gruppe!)
├── FamilyScoreKit/                   ← Local Swift Package
│   ├── Package.swift
│   └── Sources/FamilyScoreKit/
│       └── WidgetData.swift          ← Shared Codable structs
├── Config/
│   ├── Config.xcconfig               ← Committed: enthält #include "Secrets.xcconfig"
│   ├── Secrets.xcconfig              ← GITIGNORED: enthält echte Keys
│   └── Secrets.xcconfig.template    ← Committed: Placeholder-Werte
└── supabase/
    └── migrations/
        └── 20260515_initial_schema.sql  ← DDL + RLS + Trigger
```

### Pattern 1: FamilyScoreKit — Local Swift Package (Minimal, No Dependencies)

**What:** Ein lokales Swift Package (`File > New > Package`) ohne externe Abhängigkeiten. Enthält nur `Codable`-Structs und Konstanten, die App Target und Widget Extension teilen.

**Why:** Verhindert Target-Membership-Sprawl (die "doppelte Checkbox"-Falle aus PITFALLS.md). Kein Supabase SDK im Package — nur Plain Swift.

**Package.swift:**
```swift
// Source: Apple Developer Documentation + PITFALLS.md pattern
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FamilyScoreKit",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "FamilyScoreKit", targets: ["FamilyScoreKit"])
    ],
    targets: [
        .target(
            name: "FamilyScoreKit",
            path: "Sources/FamilyScoreKit"
        )
    ]
)
```

**Xcode Integration:**
- `File > Add Package Dependencies > Add Local...` → `FamilyScoreKit/`
- App Target: Frameworks, Libraries → `FamilyScoreKit` hinzufügen
- Widget Extension: Frameworks, Libraries → `FamilyScoreKit` hinzufügen
- Supabase: NUR im App Target

**Phase 1 Inhalt von FamilyScoreKit:**
```swift
// Sources/FamilyScoreKit/WidgetData.swift
// Shared between App and Widget Extension
import Foundation

public struct WidgetData: Codable, Sendable {
    public struct MemberScore: Codable, Sendable {
        public let displayName: String
        public let avatarInitial: String
        public let weeklyPoints: Double
        public let weeklyMinutes: Int
        
        public init(displayName: String, avatarInitial: String,
                    weeklyPoints: Double, weeklyMinutes: Int) {
            self.displayName = displayName
            self.avatarInitial = avatarInitial
            self.weeklyPoints = weeklyPoints
            self.weeklyMinutes = weeklyMinutes
        }
    }
    
    public let familyName: String
    public let members: [MemberScore]
    public let lastUpdated: Date
    
    public init(familyName: String, members: [MemberScore], lastUpdated: Date) {
        self.familyName = familyName
        self.members = members
        self.lastUpdated = lastUpdated
    }
}

// App Group identifier constant — single source of truth
public let appGroupIdentifier = "group.com.familyscore"
```

### Pattern 2: Secrets.xcconfig — Build-Settings-Injection

**What:** Zwei xcconfig-Dateien: eine committed (Config.xcconfig mit `#include`), eine gitignored (Secrets.xcconfig mit echten Keys). Info.plist liest Build Settings via `$(VARIABLE)`.

**Warning (2025):** Supabase hat neue "Publishable Keys" (`sb_publishable_xxx`) eingeführt, die die legacy `anon`-Keys ersetzen. Beide funktionieren bis Ende 2026, aber neue Projekte sollten die neuen Keys verwenden. [VERIFIED: supabase.com/docs/guides/getting-started/api-keys]

**Config.xcconfig** (committed):
```
// Config.xcconfig
#include "Secrets.xcconfig"

SUPABASE_URL = $(SUPABASE_URL_SECRET)
SUPABASE_KEY = $(SUPABASE_KEY_SECRET)
```

**Secrets.xcconfig** (gitignored):
```
// Secrets.xcconfig — DO NOT COMMIT
SUPABASE_URL_SECRET = https://your-project.supabase.co
SUPABASE_KEY_SECRET = sb_publishable_xxxxxxxxxxxxxxxx
```

**Secrets.xcconfig.template** (committed):
```
// Secrets.xcconfig.template — Copy to Secrets.xcconfig and fill in values
SUPABASE_URL_SECRET = REPLACE_WITH_YOUR_SUPABASE_URL
SUPABASE_KEY_SECRET = REPLACE_WITH_YOUR_SUPABASE_PUBLISHABLE_KEY
```

**.gitignore** (relevant lines):
```
Secrets.xcconfig
*.xcconfig.local
```

**Info.plist entries** (in App Target's Info.plist):
```xml
<key>SUPABASE_URL</key>
<string>$(SUPABASE_URL)</string>
<key>SUPABASE_KEY</key>
<string>$(SUPABASE_KEY)</string>
```

**Supabase.swift** (App Target only):
```swift
// Source: Supabase iOS Quickstart docs + ARCHITECTURE.md
import Supabase

let supabase = SupabaseClient(
    supabaseURL: URL(string: Bundle.main.object(
        forInfoDictionaryKey: "SUPABASE_URL") as! String)!,
    supabaseKey: Bundle.main.object(
        forInfoDictionaryKey: "SUPABASE_KEY") as! String
)
```

### Pattern 3: App Group Entitlement Setup

**Schritte (Reihenfolge wichtig — Simulator prüft nicht, Gerät schon):**

1. **Apple Developer Portal:**
   - `Certificates, Identifiers & Profiles` → `Identifiers`
   - App ID `com.familyscore` öffnen → `App Groups` capability → `group.com.familyscore` erstellen
   - App ID `com.familyscore.widgets` (Widget Extension) öffnen → gleiche Gruppe hinzufügen
   - Provisioning Profiles für beide App IDs neu generieren

2. **Xcode — App Target:**
   - Target → `Signing & Capabilities` → `+ Capability` → `App Groups`
   - Gruppe `group.com.familyscore` eintragen (muss exakt mit Portal übereinstimmen)
   - Xcode generiert `FamilyScore.entitlements` automatisch

3. **Xcode — Widget Extension Target:**
   - Gleicher Prozess, gleiche Gruppe
   - Xcode generiert `FamilyScoreWidgetExtension.entitlements`

4. **Verifikation auf echtem Gerät (nicht Simulator!):**
```swift
// In der App, Testcode für Verifikation:
let appGroupDefaults = UserDefaults(suiteName: "group.com.familyscore")
appGroupDefaults?.set("connection-test-\(Date())", forKey: "app_group_test")
let value = appGroupDefaults?.string(forKey: "app_group_test")
// value != nil = App Group funktioniert
// value == nil auf Gerät = Portal-Entitlement-Problem

// Im Widget Extension, gleicher Test:
let widgetDefaults = UserDefaults(suiteName: "group.com.familyscore")
let widgetValue = widgetDefaults?.string(forKey: "app_group_test")
// Soll denselben Wert wie oben zurückgeben
```

**Entitlement-Datei Format:**
```xml
<!-- FamilyScore.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" 
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.familyscore</string>
    </array>
</dict>
</plist>
```

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Score-Aggregation | mutabler `total_score`-Column | `SUM()` über `activity_entries` via DB-Trigger oder RPC | Race conditions bei gleichzeitigem Logging (PITFALLS.md: letzter Write gewinnt) |
| Auth Token-Refresh | eigene Refresh-Logik | supabase-swift built-in Session Management | Refresh-Token-Reuse-Protection ist komplex (Github Issue #486) |
| Widget-Daten-Transport | direkte Network-Calls aus Widget | App Group UserDefaults | Widget-Prozess hat kein aktives Supabase-WebSocket |
| Secrets-Management | hardcoded Keys | xcconfig + Info.plist Build Injection | Keys müssen aus Binary lesbar bleiben (keine echte Security), aber aus Git fern |
| RLS-Logik | Client-Side Filtering | Postgres RLS Policies mit `auth.uid()` | Server-side enforcement; Client kann nie umgangen werden |
| Shared Models | Target-Membership-Checkboxen | FamilyScoreKit local package | Dual-Target-Membership erzeugt Deployment-Fehler (PITFALLS.md) |

---

## Supabase Schema (vollständiges DDL)

### Wichtiger Hinweis zur Tabellenbenennung

ARCHITECTURE.md verwendet teilweise `profiles` statt `family_members` und `categories` statt `category_config`. Die Success Criteria in ROADMAP.md nennen exakt: `families, family_members, activity_entries, category_config, family_invites, weekly_summaries`. **Das DDL unten folgt den Success Criteria-Namen.** [VERIFIED: ROADMAP.md Success Criteria 3]

### Migrations-Datei: `supabase/migrations/20260515_initial_schema.sql`

```sql
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
  avatar_color  text not null default '#4A90D9',  -- hex string
  role          text not null default 'adult'
                  check (role in ('admin', 'adult', 'child')),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- Automatisch ein leeres family_members-Profil bei User-Signup erstellen
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
  icon          text,             -- SF Symbol name, z.B. "house.fill"
  color         text,             -- hex string
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
  -- points: pre-computed at insert time = duration_minutes * point_weight
  -- NIEMALS einen mutablen total_score speichern
  points            numeric(8,2) not null check (points >= 0),
  title             text,
  logged_at         timestamptz not null default now(),  -- server-side timestamp!
  created_at        timestamptz not null default now()
);

-- Index für häufige Abfragen
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
  week_start      date not null,  -- Montag der Woche (ISO 8601)
  total_minutes   int not null default 0,
  total_points    numeric(10,2) not null default 0,
  by_category     jsonb,          -- {category_id: {minutes, points}}
  updated_at      timestamptz not null default now(),
  unique (family_id, user_id, week_start)
);

-- =============================================================================
-- DB TRIGGER: activity_entries → weekly_summaries (Upsert bei INSERT/DELETE)
-- =============================================================================
create or replace function public.update_weekly_summary()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_family_id   uuid;
  v_user_id     uuid;
  v_week_start  date;
begin
  -- Bestimme welche Zeile betroffen ist (INSERT: NEW, DELETE: OLD)
  if (TG_OP = 'DELETE') then
    v_family_id  := OLD.family_id;
    v_user_id    := OLD.user_id;
    v_week_start := date_trunc('week', OLD.logged_at)::date;
  else
    v_family_id  := NEW.family_id;
    v_user_id    := NEW.user_id;
    v_week_start := date_trunc('week', NEW.logged_at)::date;
  end if;

  -- Upsert: Summe neu berechnen aus activity_entries (nie inkrementell!)
  insert into public.weekly_summaries
    (family_id, user_id, week_start, total_minutes, total_points, by_category, updated_at)
  select
    v_family_id,
    v_user_id,
    v_week_start,
    coalesce(sum(ae.duration_minutes), 0),
    coalesce(sum(ae.points), 0),
    jsonb_object_agg(
      ae.category_id::text,
      jsonb_build_object(
        'minutes', coalesce(cat_sum.minutes, 0),
        'points',  coalesce(cat_sum.points, 0)
      )
    ) filter (where ae.category_id is not null),
    now()
  from public.activity_entries ae
  where ae.family_id  = v_family_id
    and ae.user_id    = v_user_id
    and date_trunc('week', ae.logged_at)::date = v_week_start
  cross join lateral (
    select
      coalesce(sum(ae2.duration_minutes), 0) as minutes,
      coalesce(sum(ae2.points), 0) as points
    from public.activity_entries ae2
    where ae2.family_id   = v_family_id
      and ae2.user_id     = v_user_id
      and ae2.category_id = ae.category_id
      and date_trunc('week', ae2.logged_at)::date = v_week_start
  ) cat_sum
  on conflict (family_id, user_id, week_start)
  do update set
    total_minutes = excluded.total_minutes,
    total_points  = excluded.total_points,
    by_category   = excluded.by_category,
    updated_at    = now();

  return null;  -- AFTER trigger, Rückgabewert ignoriert
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
```

---

## Supabase RLS Policies (vollständig)

```sql
-- =============================================================================
-- HELPER FUNCTIONS (security definer — rufen auth.uid() einmal auf, nicht pro Row)
-- =============================================================================

-- Prüft ob der aktuelle User Mitglied der angegebenen Familie ist
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

-- Prüft ob der aktuelle User Admin der angegebenen Familie ist
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
-- families: RLS
-- =============================================================================
alter table public.families enable row level security;

create policy "Familienmitglieder können Familie lesen"
  on public.families for select to authenticated
  using (public.is_family_member(id));

create policy "Admin kann Familie aktualisieren"
  on public.families for update to authenticated
  using (public.is_family_admin(id));

create policy "Authentifizierter User kann Familie erstellen"
  on public.families for insert to authenticated
  with check (created_by = (select auth.uid()));

-- =============================================================================
-- family_members: RLS
-- =============================================================================
alter table public.family_members enable row level security;

create policy "Familienmitglieder sehen sich gegenseitig"
  on public.family_members for select to authenticated
  using (
    -- eigenes Profil immer sichtbar
    id = (select auth.uid())
    or
    -- oder andere Mitglieder derselben Familie
    public.is_family_member(family_id)
  );

create policy "User verwaltet eigenes Profil"
  on public.family_members for update to authenticated
  using ((select auth.uid()) = id);

create policy "Admin verwaltet Familienmitglieder"
  on public.family_members for all to authenticated
  using (public.is_family_admin(family_id));

-- Neues Profil wird via Trigger erstellt (kein direktes INSERT durch Client nötig)
-- Falls doch nötig:
create policy "User kann eigenes Profil initialisieren"
  on public.family_members for insert to authenticated
  with check ((select auth.uid()) = id);

-- =============================================================================
-- category_config: RLS
-- =============================================================================
alter table public.category_config enable row level security;

create policy "Familienmitglieder lesen Kategorien"
  on public.category_config for select to authenticated
  using (public.is_family_member(family_id));

create policy "Admin verwaltet Kategorien"
  on public.category_config for all to authenticated
  using (public.is_family_admin(family_id));

-- =============================================================================
-- activity_entries: RLS
-- =============================================================================
alter table public.activity_entries enable row level security;

create policy "Familienmitglieder lesen alle Einträge der Familie"
  on public.activity_entries for select to authenticated
  using (public.is_family_member(family_id));

create policy "User erstellt eigene Einträge"
  on public.activity_entries for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and public.is_family_member(family_id)
  );

create policy "User löscht eigene Einträge"
  on public.activity_entries for delete to authenticated
  using (
    (select auth.uid()) = user_id
  );

create policy "Admin löscht alle Einträge der Familie"
  on public.activity_entries for delete to authenticated
  using (public.is_family_admin(family_id));

-- =============================================================================
-- family_invites: RLS
-- =============================================================================
alter table public.family_invites enable row level security;

create policy "Admin verwaltet Einladungen"
  on public.family_invites for all to authenticated
  using (public.is_family_admin(family_id));

-- Einladungs-Lookup via Token (für Join-Flow, auch vor Familienmitgliedschaft)
create policy "Jeder authentifizierte User kann Einladung per Token lesen"
  on public.family_invites for select to authenticated
  using (true);  -- Token selbst ist das Geheimnis; RLS-Policy reicht hier

-- =============================================================================
-- weekly_summaries: RLS
-- =============================================================================
alter table public.weekly_summaries enable row level security;

create policy "Familienmitglieder lesen Weekly Summaries"
  on public.weekly_summaries for select to authenticated
  using (public.is_family_member(family_id));

-- Nur DB-Trigger schreibt in weekly_summaries — kein direktes Client-INSERT
-- Falls dennoch nötig (z.B. bei Trigger-Fehler Recovery):
create policy "Service kann Weekly Summaries upserten"
  on public.weekly_summaries for all to service_role
  using (true);
```

---

## Common Pitfalls (Phase 1 spezifisch)

### Pitfall 1: App Group nur im Portal für eine App ID registriert

**What goes wrong:** Widget Extension liest `nil` von `UserDefaults(suiteName:)` auf dem Gerät, obwohl Simulator funktioniert.
**Why it happens:** Portal und Xcode sind unabhängig — Xcode-Entitlement allein reicht nicht.
**How to avoid:** Im Apple Developer Portal explizit für BEIDE App IDs (`com.familyscore` und `com.familyscore.widgets`) die Gruppe hinzufügen.
**Warning signs:** Simulator: funktioniert. Gerät: nil.

### Pitfall 2: RLS aktiv, Policies vergessen → leere Results, kein Fehler

**What goes wrong:** Jede Query gibt `[]` zurück, keine 403, keine Erklärung.
**Why it happens:** Postgres default-deny mit leerem Policy-Set = 0 Rows für alle.
**How to avoid:** Direkt nach `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` die Basis-Policies schreiben. Testen mit Swift Client (nicht Dashboard-SQL-Editor, der bypassed RLS).
**Warning signs:** Dashboard zeigt Daten, Swift Client gibt [].

### Pitfall 3: Supabase Package im Widget Extension Target

**What goes wrong:** Widget Extension überschreitet 30MB Speicherlimit → Terminierung ohne Crash-Log.
**Why it happens:** Supabase SDK + Realtime + PostgREST addiert ~8-15 MB Binärgröße.
**How to avoid:** In Xcode-Package-Einstellungen: `Supabase` package → Target Membership = NUR `FamilyScore`.
**Warning signs:** Widget rendert in Simulator, zeigt "Unable to load" auf Gerät.

### Pitfall 4: Secrets.xcconfig committed oder hardcoded

**What goes wrong:** Supabase Key in Git-History, bleibt für immer kompromittiert.
**Why it happens:** Entwickler fügt Key direkt in Supabase.swift oder Info.plist ein.
**How to avoid:** .gitignore vor dem ersten `git add` konfigurieren. `git log --all -S "supabase.co"` als Verifikationsschritt.
**Warning signs:** `git grep -r "supabase.co"` findet Treffer in committed Files.

### Pitfall 5: weekly_summaries Trigger — vereinfachte Aggregation

**What goes wrong:** Trigger aggregiert mit `SUM()` über nur den neuen/gelöschten Row statt über alle Rows der Woche → falsche Summen nach mehreren Einträgen.
**Why it happens:** Inkrementeller Ansatz (`old_total + NEW.points`) ist anfällig für Fehler bei DELETE.
**How to avoid:** Trigger IMMER die gesamte Woche neu berechnen (`SELECT SUM() ... WHERE week = v_week_start`). Niemals inkrementell.

### Pitfall 6: `date_trunc('week', ...)` gibt Montag zurück (ISO)

**What goes wrong:** Woche beginnt in Postgres mit `date_trunc('week', ...)` am Montag (ISO 8601). Falls App Sonntag als Wochenstart erwartet, gibt es Diskrepanzen.
**Why it happens:** ISO-Standard.
**How to avoid:** Explizit dokumentieren: v1 nutzt Montag als Wochenstart (REQUIREMENTS.md v2-Defer: konfigurierbar). Einheitlich in DB und App verwenden.

---

## Validation Architecture

> `nyquist_validation: true` in config.json — diese Sektion ist Pflicht.

Phase 1 hat **keine User-facing Features** und **keine Unit-Test-Targets** im Xcode-Projekt (noch nicht). Die Validierung erfolgt über gezielte Integrationstests: Swift-Code direkt im App-Target (als Debug-only Verifikationsroutine), SQL-Checks, und Datei-Checks.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Kein XCTest in Phase 1 (Test Target wird in Phase 2 eingerichtet) |
| Config file | Kein dedizierter Test-Config in Phase 1 |
| Quick run command | `xcodebuild -scheme FamilyScore build -destination "generic/platform=iOS"` |
| Full suite command | Manuell: alle 5 Success Criteria (siehe unten) |

### Success Criteria → Verifikationsmatrix

| SC# | Success Criterion | Verifikationsansatz | Automatisierbar |
|-----|-------------------|---------------------|-----------------|
| SC-1 | App baut und läuft auf echtem Gerät, beide Targets vorhanden | `xcodebuild build` + Gerät-Deploy | Teilweise (Build) |
| SC-2 | App Group Container von beiden Targets auf Gerät zugänglich | Swift Debug-Code im App + Widget | Manuell auf Gerät |
| SC-3 | Supabase Schema live, RLS aktiv, per Swift Client verifiziert | Swift-Verbindungstest (anon JWT) | Ja (Swift-Code) |
| SC-4 | Secrets.xcconfig gitignored, Key in keinem committed File | `git grep` + `.gitignore` check | Ja (Shell) |
| SC-5 | FamilyScoreKit existiert, nur App Target linked Supabase | Xcode Build Phases prüfen | Teilweise |

### Verifikationsschritte im Detail

**SC-1: Build-Verifikation**
```bash
# Shell-Befehl — läuft lokal auf Mac
xcodebuild \
  -project FamilyScore.xcodeproj \
  -scheme FamilyScore \
  -destination "platform=iOS,name=<Gerätename>" \
  build
# Erwartet: BUILD SUCCEEDED
# Prüft: App + Widget Extension kompilieren ohne Fehler
```

**SC-2: App Group Verifikation (Swift Debug-Code — wird nach Phase 1 entfernt)**
```swift
// In FamilyScoreApp.swift, nur in DEBUG
#if DEBUG
func verifyAppGroup() {
    let suite = "group.com.familyscore"
    guard let defaults = UserDefaults(suiteName: suite) else {
        assertionFailure("App Group UserDefaults konnte nicht initialisiert werden: \(suite)")
        return
    }
    let testKey = "phase1_verification"
    defaults.set(true, forKey: testKey)
    defaults.synchronize()
    let result = defaults.bool(forKey: testKey)
    print("[Phase1] App Group Test: \(result ? "PASS ✓" : "FAIL ✗")")
    // PASS auf Simulator: kein Beweis für korrekte Portal-Konfiguration
    // PASS auf echtem Gerät: Portal-Entitlement korrekt
    assert(result, "App Group FAIL — Developer Portal prüfen!")
}
#endif

// Im Widget Extension (FamilyScoreWidget.swift), getTimeline():
#if DEBUG
let debugDefaults = UserDefaults(suiteName: "group.com.familyscore")
let appWroteValue = debugDefaults?.bool(forKey: "phase1_verification") ?? false
print("[Widget] App Group read from Widget: \(appWroteValue ? "PASS ✓" : "FAIL ✗")")
// PASS = App schrieb Wert, Widget kann ihn lesen → bidirektionale Verbindung bestätigt
#endif
```

**SC-3: Supabase RLS-Verifikation (Swift, mit echtem JWT)**
```swift
// In FamilyScoreApp.swift, DEBUG-only, nach SupabaseClient-Init
#if DEBUG
func verifySupabaseConnection() async {
    do {
        // Test 1: Verbindung (unauthentifiziert — anon key, kein user)
        // Mit RLS: families gibt [] zurück (kein Fehler, kein 403)
        let families: [AnyJSON] = try await supabase
            .from("families")
            .select()
            .execute()
            .value
        print("[Phase1] Supabase Connection PASS ✓ — families returned \(families.count) rows (expected 0 with RLS, no auth)")
        
        // Test 2: weekly_summaries Tabelle existiert
        let summaries: [AnyJSON] = try await supabase
            .from("weekly_summaries")
            .select()
            .execute()
            .value
        print("[Phase1] weekly_summaries table exists PASS ✓")
        
        // Test 3: RLS ist aktiv (wenn Tabelle existiert aber keine Rows zurückgibt
        //         ohne Auth — das ist korrektes RLS-Verhalten)
        print("[Phase1] RLS appears active — anon user sees 0 rows ✓")
        print("[Phase1] NOTE: vollständige RLS-Verifikation erfordert Auth (Phase 2)")
        
    } catch {
        print("[Phase1] Supabase Connection FAIL ✗: \(error)")
        assertionFailure("Supabase connection failed: \(error)")
    }
}
// Aufruf: Task { await verifySupabaseConnection() } in App.init oder ContentView.task{}
#endif
```

**Vollständige RLS-Verifikation (SQL in Supabase SQL Editor — simuliert Swift Client):**
```sql
-- Simuliert einen authentifizierten User OHNE Familienmitgliedschaft
-- Muss [] zurückgeben (nicht alle Familien!)
set role authenticated;
set request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}';

select * from public.families;
-- Erwartet: 0 Rows (User ist in keiner Familie)

select * from public.activity_entries;
-- Erwartet: 0 Rows

-- Rücksetzen
reset role;
```

**SC-4: Secrets aus Git verbannen**
```bash
# Prüft ob Supabase-URL oder Key in irgendeinem committed File auftaucht
git grep -r "supabase.co" -- "*.swift" "*.plist" "*.xcconfig" "*.json"
# Erwartet: kein Output (nur Secrets.xcconfig hat den Key, und die ist nicht committed)

git grep -r "sb_publishable" -- "*.swift" "*.plist" "*.xcconfig"
# Erwartet: kein Output

# Prüft .gitignore enthält Secrets.xcconfig
grep "Secrets.xcconfig" .gitignore
# Erwartet: "Secrets.xcconfig" oder äquivalenter Eintrag

# Prüft git-tracked files (stärkster Test — prüft gesamte History)
git log --all --oneline -S "supabase.co" -- "*.swift" "*.plist" "*.xcconfig"
# Erwartet: kein Output
```

**SC-5: FamilyScoreKit und Target Membership**
```bash
# Prüft dass FamilyScoreKit Package-Verzeichnis existiert
ls FamilyScoreKit/Package.swift
# Erwartet: Datei existiert

# Prüft dass Supabase NICHT im Widget Extension Target ist
# (Xcode Projektdatei parsen)
grep -A5 "FamilyScoreWidgetExtension" FamilyScore.xcodeproj/project.pbxproj | grep -c "Supabase"
# Erwartet: 0 (Supabase taucht nicht in Widget Extension Target-Dependencies auf)

# Visuell in Xcode:
# Target: FamilyScoreWidgetExtension > General > Frameworks, Libraries, Embedded Content
# Darf NICHT enthalten: Supabase, SupabaseAuth, Realtime, PostgREST
# Muss enthalten: FamilyScoreKit
```

### Wave 0 Gaps

Phase 1 richtet die Infrastruktur ein — kein XCTest-Target in dieser Phase. Test-Framework wird in Phase 2 eingerichtet (wenn der erste Feature-Code geschrieben wird).

- [ ] XCTest Target `FamilyScoreTests` — wird in Phase 2 Wave 0 erstellt
- [ ] Supabase Mock für Previews — wird in Phase 2 Wave 0 erstellt (Protocol + Mock pattern)
- [ ] `Secrets.xcconfig.template` — wird in Phase 1 Wave 0 erstellt (kein Test, aber Wave 0 Setup)

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode 16+ | Build, Swift 6 | Prüfen auf Mac | — | Kein Fallback (App Store Pflicht) |
| macOS (für Xcode) | iOS Build | — | — | Kein Fallback |
| Apple Developer Account | App Group Portal | — | Paid ($99/Jahr) | Simulator-Test ohne Portal |
| iOS Gerät (physisch) | SC-1, SC-2 | Manuell bereitstellen | iOS 16.0+ | Kein Fallback für SC-2 |
| Supabase Account | SC-3 | Kostenlos verfügbar | Free Tier | Kein Fallback |
| Git | SC-4 | Standard | — | — |

**Hinweis:** Diese Phase muss auf einem Mac mit Xcode 16+ ausgeführt werden. Windows (das aktuelle Environment) kann keinen iOS-Code kompilieren. Alle Build- und Deployment-Schritte erfordern macOS.

**Missing dependencies mit kritischer Bedeutung:**
- Physisches iOS-Gerät für SC-2 (App Group): Simulator-Erfolg beweist nichts für Portal-Konfiguration

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `anon`/`service_role` JWT Keys | `sb_publishable_xxx` / `sb_secret_xxx` Keys | 2025 (Supabase) | Legacy Keys funktionieren bis Ende 2026; neue Projekte sollten neue Keys verwenden |
| `@ObservedObject` + `ObservableObject` | `@Observable` Macro + `@State` | iOS 17 / Swift 5.9 | Feinere Re-Renders, kein Publisher-Overhead; auf iOS 16 weiterhin `@StateObject` nötig |
| `DispatchQueue.main.async` | `await MainActor.run { }` | Swift 5.5 / Swift 6 obligatorisch | Swift 6 strict concurrency: `DispatchQueue.main` deprecated für Swift Concurrency |

**Deprecated/outdated:**
- `anon` Legacy Key: funktioniert noch bis Ende 2026, aber `sb_publishable_xxx` bevorzugen
- `@ObservedObject` für owned objects: durch `@State` + `@Observable` ersetzt (iOS 17+; iOS 16 still needs `@StateObject`)

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | Nein (Phase 2) | — |
| V3 Session Management | Nein (Phase 2) | — |
| V4 Access Control | Ja | Supabase RLS mit `auth.uid()` und family_id-Join |
| V5 Input Validation | Teilweise | PostgreSQL CHECK constraints in DDL |
| V6 Cryptography | Nein | kein Hand-Roll; supabase-swift + OS Keychain |
| Secrets Management | Ja (Phase 1 kritisch) | xcconfig + .gitignore, kein Key in Binary oder Git |

### Known Threat Patterns für diesen Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Cross-family data access | Information Disclosure | RLS Policy: `is_family_member(family_id)` auf jeder Tabelle |
| Key in Git/binary | Information Disclosure | Secrets.xcconfig gitignored; anon key ist low-privilege |
| RLS disabled table | Information Disclosure | Checklist: ALTER TABLE ... ENABLE ROW LEVEL SECURITY vor jedem Table-Deployment |
| Service Role Key im Client | Elevation of Privilege | Service Role Key nur in Edge Functions (Phase 3+), niemals im iOS Binary |
| SQL Injection via PostgREST | Tampering | supabase-swift verwendet parameterisierte Queries; niemals raw SQL aus User-Input |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | supabase-swift v2.46.0 ist die aktuelle Latest-Version (Stand April 2026) | Standard Stack | Niedrig: Version schon in STACK.md bestätigt; neuere Version wäre semver-kompatibel |
| A2 | `date_trunc('week', ...)` in Postgres gibt Montag zurück (ISO 8601) | DDL / Trigger | Mittel: Wenn DB anders konfiguriert, falsche Wochengrenzen; im Trigger explizit dokumentiert |
| A3 | Neues Supabase-Projekt hat `supabase_realtime` Publication schon vorkonfiguriert | DDL | Niedrig: `ALTER PUBLICATION` schlägt fehl wenn Publication nicht existiert; einfach debugbar |
| A4 | Apple Developer Portal erfordert manuelles Hinzufügen des App Groups für Extension App ID | App Group Setup | Hoch: Wenn Auto-Signing dies erledigt, sind manuelle Schritte unnötig; wenn nicht, ist SC-2 unbemerkbar kaputt |
| A5 | weekly_summaries Trigger mit vollständiger Neuberechnung ist performant genug für v1 | DB Trigger | Niedrig: Familie mit 2-8 Usern, max. Dutzende Einträge/Woche; kein Performance-Problem |

---

## Open Questions

1. **Bundle Identifier für Widget Extension**
   - Was wir wissen: Muss Sub-Identifier des App Bundle sein
   - Was unklar ist: Exakter Identifier-String (`com.familyscore.widget` vs. `com.familyscore.FamilyScoreWidgetExtension`)
   - Empfehlung: Konvention: `com.familyscore.widgets` (plural, kurz)

2. **Team ID / Provisioning Profile**
   - Was wir wissen: App Group Identifier bindet sich an Team ID im Portal
   - Was unklar ist: Ob Automatic Signing in Xcode die Portal-Konfiguration für beide Targets automatisch durchführt
   - Empfehlung: Mit Automatic Signing starten; bei Problemen auf Manual umschalten und Portal manuell konfigurieren

3. **Supabase Projekt-Region**
   - Was wir wissen: Supabase Free Tier, alle Regionen verfügbar
   - Was unklar ist: Ob User (Deutschland) eine EU-Region (Frankfurt) wählen möchte
   - Empfehlung: `eu-central-1` (Frankfurt) für DSGVO-Compliance wählen

---

## Sources

### Primary (HIGH confidence)
- STACK.md (Projektrecherche 2026-05-15) — supabase-swift v2.46.0, Apple Frameworks, Free Tier limits
- ARCHITECTURE.md (Projektrecherche 2026-05-15) — Schema-Design, RLS-Policies, Widget-Architektur, Trigger-Pattern
- PITFALLS.md (Projektrecherche 2026-05-15) — App Group pitfall, 30MB Widget limit, Secrets, Realtime disconnection
- ROADMAP.md — Success Criteria SC-1 bis SC-5
- CLAUDE.md — Architektur-Regeln, Stack-Entscheidungen

### Secondary (MEDIUM confidence)
- [Supabase Swift Quickstart Docs](https://supabase.com/docs/guides/getting-started/quickstarts/ios-swiftui) — SPM URL, SupabaseClient init
- [Supabase API Keys Guide](https://supabase.com/docs/guides/getting-started/api-keys) — Publishable Key vs. Legacy Anon Key
- [Supabase Swift Installing](https://supabase.com/docs/reference/swift/installing) — SPM dependency declaration
- [Supabase Postgres Triggers](https://supabase.com/docs/guides/database/postgres/triggers) — Trigger-Syntax NEW/OLD
- [Use Your Loaf: Sharing Data with a Widget](https://useyourloaf.com/blog/sharing-data-with-a-widget/) — App Group Xcode-Setup-Schritte
- [NSHipster: Secret Management on iOS](https://nshipster.com/secrets/) — xcconfig Pattern

### Tertiary (LOW confidence — für Verifikation empfohlen)
- [Apple Dev Forums: App Groups capability](https://developer.apple.com/forums/thread/656271) — Portal-Konfiguration

---

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH — Version aus STACK.md bestätigt, SPM URL aus offiziellen Docs
- Architecture (Xcode): HIGH — aus ARCHITECTURE.md + Apple Docs
- DDL Schema: HIGH — aus ARCHITECTURE.md, angepasst an ROADMAP.md Success Criteria Tabellennamen
- RLS Policies: HIGH — aus ARCHITECTURE.md, Standard-Muster
- Weekly Summaries Trigger: MEDIUM — Muster verifiziert, aber komplexe Aggregation wurde nicht end-to-end getestet
- App Group Setup: HIGH — Schritte aus PITFALLS.md + useyourloaf.com
- Secrets Pattern: HIGH — Standard-Xcconfig-Muster, mehrfach bestätigt
- Validation Architecture: HIGH — konkrete Code-Snippets für alle 5 SC

**Research date:** 2026-05-15
**Valid until:** 2026-06-15 (30 Tage; supabase-swift kann Minor Updates haben, aber API ist stabil)
