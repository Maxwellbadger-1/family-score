# Architecture Patterns — Family Score

**Domain:** Native iOS family activity tracking app (SwiftUI + Supabase)
**Researched:** 2026-05-15
**Confidence:** HIGH (Supabase Swift SDK docs, Apple WidgetKit docs, production RLS patterns verified)

---

## 1. Data Model — Supabase PostgreSQL Schema

### Core Tables

```sql
-- Family groups (the multi-tenant boundary)
create table families (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  created_at  timestamptz default now(),
  created_by  uuid references auth.users(id)
);

-- Extended user profiles (one per auth.users row)
create table profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  family_id   uuid references families(id),
  display_name text not null,
  avatar_url  text,
  role        text not null check (role in ('admin', 'adult', 'child')),
  -- 'admin'  → parent who created the family, full settings access
  -- 'adult'  → full activity logging, no settings access
  -- 'child'  → simplified UI, restricted category set
  created_at  timestamptz default now()
);

-- Invite tokens (the join mechanism for family groups)
create table family_invites (
  id          uuid primary key default gen_random_uuid(),
  family_id   uuid not null references families(id) on delete cascade,
  created_by  uuid not null references auth.users(id),
  role        text not null check (role in ('admin', 'adult', 'child')),
  token       text not null unique default encode(gen_random_bytes(12), 'base64'),
  used_by     uuid references auth.users(id),
  used_at     timestamptz,
  expires_at  timestamptz default (now() + interval '7 days'),
  created_at  timestamptz default now()
);

-- Activity categories (configurable per family, with defaults)
create table categories (
  id            uuid primary key default gen_random_uuid(),
  family_id     uuid references families(id) on delete cascade,
  name          text not null,
  icon          text,           -- SF Symbol name
  color         text,           -- hex string
  point_weight  numeric(5,2) not null default 1.0,
  -- points = duration_minutes * point_weight
  time_equity   boolean default true,  -- include in equity visualization
  is_enabled    boolean default true,
  sort_order    int default 0,
  created_at    timestamptz default now(),
  -- null family_id = system default (seeded on family creation)
  unique (family_id, name)
);

-- Individual activity entries
create table activity_entries (
  id              uuid primary key default gen_random_uuid(),
  family_id       uuid not null references families(id),
  user_id         uuid not null references auth.users(id),
  category_id     uuid not null references categories(id),
  duration_minutes int not null check (duration_minutes > 0),
  points          numeric(8,2) not null,  -- pre-computed: duration * point_weight
  notes           text,
  logged_at       timestamptz not null default now(),
  created_at      timestamptz default now()
);

-- Materialised weekly summary (updated via DB trigger or Edge Function)
create table weekly_summaries (
  id              uuid primary key default gen_random_uuid(),
  family_id       uuid not null references families(id),
  user_id         uuid not null references auth.users(id),
  week_start      date not null,  -- Monday of the week (ISO 8601)
  total_minutes   int not null default 0,
  total_points    numeric(10,2) not null default 0,
  by_category     jsonb,  -- {category_id: {minutes, points}}
  updated_at      timestamptz default now(),
  unique (family_id, user_id, week_start)
);
```

### Points Computation Rule

Points are **pre-computed at insert time** (`points = duration_minutes * category.point_weight`) and stored in `activity_entries`. Do not recompute on every read. If a category's weight changes, that only affects future entries — this is intentional and avoids retroactive changes surprising users.

### Weekly Summary Strategy

Use a PostgreSQL **trigger** on `activity_entries` (INSERT/DELETE) to upsert into `weekly_summaries`. The trigger runs `ON INSERT OR DELETE` and recalculates the affected user+week row. This keeps summaries always current without a separate cron job and is what the widget reads via App Groups (not direct DB queries).

```sql
-- Enable realtime replication for the tables widgets and app care about
alter publication supabase_realtime add table activity_entries;
alter publication supabase_realtime add table weekly_summaries;
alter publication supabase_realtime add table profiles;
```

---

## 2. Row Level Security (RLS)

### Core Security Definer Functions

```sql
-- Check if current user belongs to a family (called from policies)
create or replace function public.is_family_member(p_family_id uuid)
returns boolean
language sql
security definer
set search_path = ''
as $$
  select exists(
    select 1 from public.profiles
    where user_id = (select auth.uid())
      and family_id = p_family_id
  );
$$;

-- Check if current user is admin for a family
create or replace function public.is_family_admin(p_family_id uuid)
returns boolean
language sql
security definer
set search_path = ''
as $$
  select exists(
    select 1 from public.profiles
    where user_id = (select auth.uid())
      and family_id = p_family_id
      and role = 'admin'
  );
$$;
```

### Key Policies

```sql
-- Families: members can read; admin can update
alter table families enable row level security;
create policy "family members can read"
  on families for select to authenticated
  using (public.is_family_member(id));
create policy "admin can update family"
  on families for update to authenticated
  using (public.is_family_admin(id));

-- Profiles: family members see each other
alter table profiles enable row level security;
create policy "family members see profiles"
  on profiles for select to authenticated
  using (public.is_family_member(family_id));
create policy "user manages own profile"
  on profiles for update to authenticated
  using ((select auth.uid()) = id);

-- Activity entries: family can read all, user writes own
alter table activity_entries enable row level security;
create policy "family reads all entries"
  on activity_entries for select to authenticated
  using (public.is_family_member(family_id));
create policy "user inserts own entries"
  on activity_entries for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and public.is_family_member(family_id)
  );
create policy "user deletes own entries within 24h"
  on activity_entries for delete to authenticated
  using (
    (select auth.uid()) = user_id
    and created_at > now() - interval '24 hours'
  );

-- Categories: family reads all, admin manages
alter table categories enable row level security;
create policy "family reads categories"
  on categories for select to authenticated
  using (public.is_family_member(family_id));
create policy "admin manages categories"
  on categories for all to authenticated
  using (public.is_family_admin(family_id));

-- Invites: admin creates/reads, anyone can read by token (for join flow)
alter table family_invites enable row level security;
create policy "admin manages invites"
  on family_invites for all to authenticated
  using (public.is_family_admin(family_id));
```

**Performance note:** Wrap all `auth.uid()` calls in `(select auth.uid())` — this evaluates once per query, not once per row. Index `profiles(user_id, family_id)` and `activity_entries(family_id, user_id, logged_at desc)`.

---

## 3. iOS App Architecture — Layer Structure

### Recommended Pattern: MVVM + @Observable + Service Layer

TCA has a steep learning curve and is over-engineered for a family app of this scope. Vanilla @Observable with no ViewModels becomes unmanageable with real-time state. **MVVM with @Observable service layer** is the right fit: testable, SwiftUI-idiomatic, and well-understood.

```
┌─────────────────────────────────────────────────┐
│                   SwiftUI Views                  │
│  (pure rendering, bind to ViewModels via @State) │
└──────────────────────┬──────────────────────────┘
                       │ owns
┌──────────────────────▼──────────────────────────┐
│              @Observable ViewModels              │
│  (screen-scoped, lifecycle tied to view @State)  │
└──────────────────────┬──────────────────────────┘
                       │ calls
┌──────────────────────▼──────────────────────────┐
│           @Observable Service Layer              │
│  FamilyService | ActivityService | AuthService   │
│  (app-scoped singletons, injected via Environment)│
└──────────────────────┬──────────────────────────┘
                       │ wraps
┌──────────────────────▼──────────────────────────┐
│              SupabaseClient (singleton)          │
│  supabase.auth | supabase.database | supabase.   │
│  realtime | supabase.functions                   │
└─────────────────────────────────────────────────┘
```

### SupabaseClient Placement

One single `SupabaseClient` instance for the whole app lifecycle. Initialized at app startup and passed through the SwiftUI Environment via a `DependencyContainer`.

```swift
// Supabase.swift — module-level singleton
let supabase = SupabaseClient(
    supabaseURL: URL(string: Bundle.main.object(
        forInfoDictionaryKey: "SUPABASE_URL") as! String)!,
    supabaseKey: Bundle.main.object(
        forInfoDictionaryKey: "SUPABASE_ANON_KEY") as! String
)

// DependencyContainer.swift
@Observable
final class AppContainer {
    let authService: AuthService
    let activityService: ActivityService
    let familyService: FamilyService

    init() {
        authService    = AuthService(client: supabase)
        activityService = ActivityService(client: supabase)
        familyService  = FamilyService(client: supabase)
    }
}

// FamilyScoreApp.swift
@main struct FamilyScoreApp: App {
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(container)
        }
    }
}
```

### Offline Strategy: Online-Required with Optimistic UI

Full offline-first (CoreData + sync engine) is a significant scope increase for v1. The right v1 posture is **online-required with optimistic UI**:

- Activity entries are inserted locally into an in-memory list immediately (optimistic), then persisted to Supabase. On failure, roll back and show error.
- App shows a connection banner when Supabase is unreachable.
- No local database for v1. Re-evaluate with SwiftData or PowerSync for v2 if user demand warrants it.

This is not a compromise — it is the correct scope decision. Families are typically on WiFi at home; the offline case is rare and not worth the complexity tax upfront.

---

## 4. Widget Architecture

### Constraints (Hard Limits from Apple)

- Widget extension runs in its own process — it **cannot** access the main app's memory or active Supabase WebSocket.
- Widgets **can** make URLSession network calls inside `getTimeline()`, but these are budget-limited and unreliable for fresh data.
- The only reliable cross-process channel is **App Groups** (shared container).

### Recommended Architecture: App Groups + WidgetCenter Refresh

```
Main App                          Widget Extension
────────────────────              ─────────────────────────
Supabase Realtime →               TimelineProvider.getTimeline()
  receives update  →                reads from App Groups
  writes to        →              UserDefaults(suiteName: "group.com.yourapp")
  App Groups       →                → renders widget
  WidgetCenter.shared
    .reloadAllTimelines()
```

### Shared Data Format

Write a compact `WidgetData` struct to shared UserDefaults (encoded as JSON):

```swift
struct WidgetData: Codable {
    struct MemberScore: Codable {
        let displayName: String
        let avatarInitial: String
        let weeklyPoints: Double
        let weeklyMinutes: Int
    }
    let familyName: String
    let members: [MemberScore]
    let lastUpdated: Date
}

// Written by main app after every realtime update:
let defaults = UserDefaults(suiteName: "group.com.familyscore")!
let data = try! JSONEncoder().encode(widgetData)
defaults.set(data, forKey: "widgetData")
WidgetCenter.shared.reloadAllTimelines()
```

### Widget Timeline Provider

```swift
struct FamilyScoreProvider: TimelineProvider {
    func getTimeline(in context: Context, completion: @escaping (Timeline<FamilyScoreEntry>) -> Void) {
        let defaults = UserDefaults(suiteName: "group.com.familyscore")!

        if let data = defaults.data(forKey: "widgetData"),
           let widgetData = try? JSONDecoder().decode(WidgetData.self, from: data) {
            // Use cached data written by main app
            let entry = FamilyScoreEntry(date: .now, data: widgetData)
            let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        } else {
            // Fallback: widget can make a direct network call here as a last resort
            // Use URLSession (not SupabaseClient — no shared instance)
            completion(Timeline(entries: [.placeholder], policy: .after(.now.addingTimeInterval(300))))
        }
    }
}
```

### Widget Refresh Triggers (in priority order)

1. **Realtime update arrives in main app** → app writes to App Groups → calls `WidgetCenter.shared.reloadAllTimelines()` — most reliable, near-instant.
2. **WidgetKit push notification** (iOS 16+) → server sends APNs push with `content-available: 1` to the widget's push token — works even when app is not running, budgeted by iOS.
3. **Timeline policy** (hourly fallback) → widget refreshes itself on schedule, makes a network call in `getTimeline()` — last resort.

For v1, implement only trigger #1. Add #2 (server-side push via Supabase Edge Function) in a later phase.

---

## 5. Real-time Architecture

### PostgreSQL Changes (recommended over Broadcast)

Use Supabase Realtime **Postgres Changes** rather than Broadcast channels for activity entries and weekly summaries. Postgres Changes are automatically consistent with the database; Broadcast is ephemeral and can be missed.

```swift
// ActivityService.swift
@Observable
final class ActivityService {
    private(set) var entries: [ActivityEntry] = []
    private var channel: RealtimeChannelV2?

    func startListening(familyId: String) async {
        let channel = await supabase.channel("family-\(familyId)")

        let changes = await channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "activity_entries",
            filter: .eq("family_id", value: familyId)
        )
        await channel.subscribe()
        self.channel = channel

        for await change in changes {
            switch change {
            case .insert(let action):
                let entry = try? action.decodeRecord(as: ActivityEntry.self)
                if let entry { entries.append(entry) }
            case .delete(let action):
                let id = action.oldRecord["id"]?.stringValue
                entries.removeAll { $0.id.uuidString == id }
            default: break
            }
            updateWidgetCache()
        }
    }

    func stopListening() async {
        await channel?.unsubscribe()
        channel = nil
    }

    private func updateWidgetCache() {
        // Serialize current state → App Groups UserDefaults
        // Call WidgetCenter.shared.reloadAllTimelines()
    }
}
```

### Reconnection Handling

Supabase Swift client uses exponential backoff by default. Augment with:

1. Subscribe to the channel's status callback — on `CHANNEL_ERROR` or `TIMED_OUT`, show a subtle banner.
2. On `SUBSCRIBED` after a reconnect, **re-fetch the last N entries** from the DB to catch any missed changes during the gap.
3. iOS background: when the app re-enters foreground (`scenePhase == .active`), call `startListening()` again if channel is not active.

```swift
// In your @main App or scene modifier:
.onChange(of: scenePhase) { _, newPhase in
    if newPhase == .active {
        Task { await activityService.ensureConnected(familyId: familyId) }
    }
}
```

### Push Notifications for Family Activity

Use **Supabase Database Webhooks** (or a Postgres trigger calling a Supabase Edge Function) to send an APNs silent push when a family member logs an activity. The main app receives the push in background and triggers a data refresh. Do not use realtime Broadcast for this — it requires the WebSocket to be active.

---

## 6. Authentication Flow & Family Join

### Sign-Up and Family Creation

```
New user signs up (email/password or Sign in with Apple)
    ↓
Auth trigger creates empty profile in `profiles` table
    ↓
Onboarding: "Create family" or "Join with invite code"
    ↓ Create path:
        Insert into `families`, update own profile with family_id and role=admin
        Seed default categories for the family
    ↓ Join path:
        Look up `family_invites` by token (unauthenticated RPC or public select)
        Call supabase.rpc("accept_invite", params: {token: "..."})
        Edge function / RPC validates token, updates profile, marks invite used
```

### Invite Code Design

```sql
-- RPC callable by authenticated users (no admin required to call, but
-- validates the token itself contains the authorization)
create or replace function public.accept_invite(invite_token text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_invite family_invites%rowtype;
begin
  select * into v_invite
  from public.family_invites
  where token = invite_token
    and used_by is null
    and expires_at > now();

  if not found then
    raise exception 'Invalid or expired invite';
  end if;

  -- Assign user to family with invite's role
  update public.profiles
  set family_id = v_invite.family_id,
      role      = v_invite.role
  where id = (select auth.uid());

  -- Mark invite as used
  update public.family_invites
  set used_by = (select auth.uid()),
      used_at = now()
  where id = v_invite.id;
end;
$$;
```

### Deep Link Handling (iOS)

Invite links use a universal link or custom scheme:
`familyscore://invite?token=abc123`

```swift
// In FamilyScoreApp.swift
.onOpenURL { url in
    if let token = parseInviteToken(from: url) {
        navigationPath.append(Route.joinFamily(token: token))
    }
}
```

### Child Accounts

Two options — recommend Option A for v1:

**Option A (recommended): Parent creates child account**
- Parent signs up for a new email account on behalf of the child (e.g., `child@family.com`)
- Parent generates an invite, accepts it on behalf of the child with role=child
- Child uses the same device as parent, or parent hands them a device with the child session
- No need for parental consent flows under COPPA/GDPR-K for v1 (parent operates the account)

**Option B (deferred): Separate child auth flow**
- Child signs up via Sign in with Apple (no email required)
- Requires implementing parental consent UI
- Higher complexity, needed only if child uses their own device independently
- Defer to Phase 3+

---

## 7. Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| `SupabaseClient` | Network transport, auth token injection | AuthService, ActivityService, FamilyService |
| `AuthService` | Session management, sign-in/up/out, auth state stream | All ViewModels via Environment |
| `FamilyService` | Family CRUD, invite create/accept, member list | FamilyViewModel, SettingsViewModel |
| `ActivityService` | Entry CRUD, realtime subscription, widget cache write | ActivityLogViewModel, DashboardViewModel |
| `CategoryService` | Category CRUD, point weight management | SettingsViewModel, ActivityLogViewModel |
| `WidgetDataWriter` | Encodes `WidgetData` → App Groups UserDefaults, calls WidgetCenter reload | ActivityService (called after every mutation) |
| Widget Extension | Reads App Groups, renders timeline, calls URLSession as fallback | App Groups only (no direct Supabase) |
| `FamilyScoreApp` | DependencyContainer creation, Environment injection, deep link routing | All |

---

## 8. Data Flow — Activity Logging

```
User taps "Log Activity"
    ↓
ActivityLogViewModel.submit(category, duration)
    ↓ [optimistic] appends to local entries list
    ↓
ActivityService.insert(entry)
    ↓ await supabase.from("activity_entries").insert(entry)
    ↓ [on success] no-op (realtime will confirm via subscription)
    ↓ [on failure] roll back optimistic entry, show error
    ↓
Supabase writes to DB
    → DB trigger recalculates weekly_summaries
    → Realtime broadcasts change to all connected family clients
    ↓
ActivityService (via realtime channel)
    → updates entries array
    → calls WidgetDataWriter.update()
    → WidgetCenter.shared.reloadAllTimelines()
    ↓
Widget Extension picks up new App Groups data on next timeline evaluation
```

---

## 9. Build Order Implications

### Phase 1 — Foundation (must be first, everything depends on this)
- Supabase project setup: schema, RLS policies, publications
- `SupabaseClient` singleton, `AuthService`
- Sign up / sign in / sign out UI
- `profiles` table trigger on auth user creation
- `DependencyContainer` + Environment injection

### Phase 2 — Family Core (depends on Phase 1 auth)
- `families`, `categories`, `activity_entries` tables (already in schema)
- Family creation flow
- Invite code generation + deep link handling + `accept_invite` RPC
- `FamilyService`, `CategoryService`
- Default category seeding

### Phase 3 — Activity Logging + Dashboard (depends on Phase 2)
- `ActivityService` with insert + optimistic update
- Activity log screen (category picker, duration input)
- Dashboard: family member list with weekly points
- Weekly summary trigger in DB
- Time equity visualization (chart showing proportional contribution)

### Phase 4 — Real-time + Widgets (depends on Phase 3)
- Supabase Realtime subscription in `ActivityService`
- Reconnection handling + missed-change re-fetch
- App Groups setup + `WidgetDataWriter`
- WidgetKit extension with `FamilyScoreProvider`
- Widget UI (scoreboard, equity bar)

### Phase 5 — Settings + Polish (can partially parallel Phase 4)
- Category management UI (admin only): add/remove/toggle/reweight
- Role-based UI gating (child simplified view)
- Push notifications via Edge Function webhook
- Point history / export

### Parallel-safe within phases
- Widget UI layout can be designed while Phase 3 backend is in progress
- Category management UI (Phase 5) can be built while Phase 4 realtime is being wired
- RLS policies for all tables can be written in Phase 1 even before the app screens exist

---

## 10. Key Architecture Decisions (Rationale)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| iOS architecture | MVVM + @Observable | Right complexity level; TCA is overkill for this scope |
| Offline strategy | Online-required + optimistic UI | Family apps are home WiFi use cases; full offline adds 2-3x complexity |
| Widget data | App Groups UserDefaults | Widgets cannot share process; App Groups is the only reliable synchronous channel |
| Points storage | Pre-computed at insert | Avoids recomputation on every read; retroactive weight changes are intentional exclusion |
| Summary aggregation | DB trigger | Always current; avoids cron drift; no additional infrastructure |
| Realtime channel | Postgres Changes (not Broadcast) | Durable, consistent with DB, automatically filtered by RLS |
| Child accounts v1 | Parent-managed accounts | Avoids COPPA consent complexity; revisit if children need independent devices |
| Invite mechanism | Token in `family_invites` table | Simple, auditable, expiry-safe; no third-party service needed |

---

## Sources

- [Supabase Swift SDK — Official Docs](https://supabase.com/docs/reference/swift/introduction)
- [Supabase Realtime — Postgres Changes](https://supabase.com/docs/guides/realtime/postgres-changes)
- [Supabase RLS Best Practices — MakerKit](https://makerkit.dev/blog/tutorials/supabase-rls-best-practices)
- [Supabase iOS + SwiftUI Quickstart](https://supabase.com/docs/guides/getting-started/quickstarts/ios-swiftui)
- [Supabase Realtime Reconnection Strategies](https://eastondev.com/blog/en/posts/dev/supabase-realtime-practice/)
- [WidgetKit — Keeping a Widget Up to Date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date)
- [WidgetKit Push Notifications](https://developer.apple.com/documentation/widgetkit/updating-widgets-with-widgetkit-push-notifications)
- [Supabase Native Mobile Deep Linking](https://supabase.com/docs/guides/auth/native-mobile-deep-linking)
- [Modern iOS Architecture 2025](https://medium.com/@csmax/the-ultimate-guide-to-modern-ios-architecture-in-2025-9f0d5fdc892f)
- [Sharing Data Between App and Widget](https://useyourloaf.com/blog/sharing-data-with-a-widget/)
- [Supabase Invite Implementation Discussion](https://github.com/orgs/supabase/discussions/6055)
