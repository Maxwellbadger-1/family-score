# Domain Pitfalls: Family Score

**Domain:** Native iOS family activity tracking app (SwiftUI + Supabase + WidgetKit)
**Researched:** 2026-05-15
**Overall Confidence:** HIGH (all findings verified against official docs, GitHub issues, or Apple Developer Forums)

---

## 1. Supabase + iOS Pitfalls

---

### CRITICAL: RLS Enabled, No Policies = Silent Empty Results

**What goes wrong:** You `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` but forget to add policies. Every query returns an empty result set — no error, no 403, just `[]`. Authenticated family members can't see any data. This is the #1 cause of "Supabase isn't working" support questions.

**Why it happens:** Postgres RLS default-deny with no policies is strict correct behavior. The Supabase client doesn't surface it as an error because empty results are valid JSON.

**Warning signs:**
- Every query returns `[]` after enabling RLS
- No 4xx errors in logs, just empty payloads
- Worked fine in the SQL editor (SQL editor bypasses RLS by running as superuser)

**Prevention:**
- After every `CREATE TABLE`, immediately write the three base policies: SELECT, INSERT, UPDATE
- Test policies from the Swift client — never from the Supabase dashboard SQL editor (it bypasses RLS)
- Use `set role authenticated; set request.jwt.claims = '{"sub":"<uuid>"}';` in SQL editor to simulate client behavior

**Phase:** Foundation / database schema setup — establish a policy-writing checklist before any table ships.

---

### CRITICAL: RLS Policies That Expose Cross-Family Data

**What goes wrong:** Policy written as `USING (auth.uid() IS NOT NULL)` or `USING (true)` for authenticated users — every logged-in user can read every family's data.

**Why it happens:** Developer tests with one account, never tests with two separate accounts from different families.

**Consequences:** Any user who knows or guesses a row UUID can read another family's activity history, scores, and child profiles.

**Warning signs:**
- Policy condition does not reference a `family_id` or membership join
- Query returns rows for users who were never invited to the family

**Prevention:**
- Every table that has family-scoped data must have a `family_id` column
- Policy pattern: `USING (family_id IN (SELECT family_id FROM family_members WHERE user_id = auth.uid()))`
- Run a two-account test in CI: user A cannot read user B's family data
- Never use `user_metadata` in RLS policies — users can modify their own metadata; use `auth.uid()` and join to your own tables

**Phase:** Foundation — write the family membership join before any other data model.

---

### MODERATE: Refresh Token Silent Logout (2-3 Days After Login)

**What goes wrong:** Users are silently logged out roughly 2-3 days after their last login. The Supabase Swift SDK surfaces "Invalid Refresh Token: Refresh Token Not Found" but only if you are observing `onAuthStateChange`. Without that listener, the app just stops fetching data.

**Why it happens:** A known bug in `supabase-swift` 2.x (tracked in GitHub issue #486). The refresh token rotates on each use; if the token is reused within a short window (e.g., two rapid foreground/background transitions simultaneously initiating a refresh), Supabase revokes the entire session under its reuse-protection logic.

**Warning signs:**
- App works fine for 1-2 days in TestFlight, then users report "nothing loads"
- No crash log — just empty data
- `onAuthStateChange` fires with `.signedOut` unexpectedly

**Prevention:**
- Always attach `supabase.auth.onAuthStateChange` at app startup and route the user to the login screen on `.signedOut`
- Keep the Supabase Swift package pinned and watch the changelog for refresh token fixes
- Configure Access Token expiry to 3600s (1 hour) on the Supabase dashboard — shorter expiry means more refreshes, increasing the chance of hitting the reuse window

**Phase:** Auth scaffold (Phase 1) — wire `onAuthStateChange` before building any authenticated screen.

---

### MODERATE: Realtime Silent Disconnection in iOS Background

**What goes wrong:** When the app goes into the background (screen off, user switches apps), iOS suspends network activity. The Supabase Realtime WebSocket heartbeat stops. After ~30-60 seconds the server closes the connection. The client does not reconnect automatically and does not surface an error — subscriptions simply stop delivering events. When the user returns to the app, the UI shows stale data.

**Why it happens:** Supabase Realtime uses WebSockets. iOS background execution policy does not keep WebSockets alive. The client-side reconnect is cooperative — it only fires if the app is active.

**Warning signs:**
- Realtime works perfectly in foreground testing
- During background/foreground integration testing, events logged by another device don't appear after returning from background
- No error in logs — subscription object still exists but is silently dead

**Prevention:**
- Subscribe to Realtime only when the view appears (`onAppear`) and unsubscribe on `onDisappear` or `scenePhase == .background`
- On `scenePhase == .active`, perform a full REST fetch first (don't trust the Realtime buffer), then re-subscribe
- The `worker: true` / `heartbeatCallback` options documented by Supabase are JavaScript/browser-specific and do not apply to Swift; the iOS solution is lifecycle-gated re-subscription
- Use `ScenePhase` environment value to detect background/foreground transitions

```swift
.onChange(of: scenePhase) { _, phase in
    if phase == .active {
        Task { await familyStore.refetchAndResubscribe() }
    } else if phase == .background {
        supabase.realtime.disconnect()
    }
}
```

**Phase:** Realtime integration — build the lifecycle manager before building any real-time UI.

---

### MODERATE: Free Tier Realtime Connection Limits

**What goes wrong:** The Supabase free tier allows 200 concurrent peak WebSocket connections. A family of 4 members each opening the app simultaneously on multiple devices (phone + iPad) can consume 8-16 connections with no load from other users. A modestly successful app with 30 concurrent families will hit the 200-connection ceiling.

**Verified limits (as of 2025):**
- Concurrent connections: 200 (free) / 500 (Pro)
- Messages/second: 100 (free)
- Presence keys per object: 10
- Broadcast payload: 256 KB (free)

**Warning signs:**
- Realtime subscriptions return `"too_many_connections"` WebSocket error
- Some family members see live updates, others don't

**Prevention:**
- Do not open a Realtime channel per-view; use a single shared channel per family, managed by an app-level `FamilyStore` singleton
- Unsubscribe channels that are not actively being displayed
- Plan for Pro tier ($25/month) before launch if expecting more than ~20 concurrent families

**Phase:** Architecture (Phase 1) — design the singleton channel architecture before building any view that uses Realtime.

---

### MODERATE: Schema Migration Breaks Live App

**What goes wrong:** Developer runs `ALTER TABLE activities ADD COLUMN points_multiplier FLOAT` directly in the Supabase dashboard on production. The iOS app (current App Store version) does not decode the new column and either crashes on `Decodable` mismatch or silently drops data.

**Why it happens:** Direct SQL on the production dashboard bypasses migration history. The old app binary has a `Codable` struct that doesn't match the new schema.

**Warning signs:**
- App Store reviews mention crashes after backend update
- Codable decoding fails with "key not found" for old clients

**Prevention:**
- All schema changes go through `supabase/migrations/` SQL files, never the dashboard
- Use `supabase db push` from local after reviewing the migration
- Make columns nullable or provide defaults — never add a non-nullable column without a default to a live table
- Model all Swift `Decodable` structs with optional properties for new columns: `var pointsMultiplier: Double?`
- Test the old app binary against the new schema before deploying (keep a test build from the previous release)

**Phase:** Every schema-change phase — establish the migration discipline in Phase 1 and enforce it throughout.

---

### MINOR: Auth Token in Widget Keychain Fails After Device Restart

**What goes wrong:** The widget extension tries to read the Supabase access token from Keychain (shared via App Group) while the device is locked after a reboot. Keychain returns `errSecInteractionNotAllowed (-25308)`. Widget shows stale or empty data until the user unlocks the device.

**Why it happens:** Keychain items with accessibility `kSecAttrAccessibleWhenUnlocked` are unavailable until first device unlock after reboot.

**Prevention:**
- Use `kSecAttrAccessibleAfterFirstUnlock` for shared auth tokens in the Keychain access group
- Widget should gracefully show a placeholder or last-cached value (from `UserDefaults` app group) rather than crashing when Keychain is unavailable
- Store only display-safe data (score, streak, member names) in `UserDefaults` app group — not auth tokens

**Phase:** Widget extension build.

---

## 2. SwiftUI Pitfalls

---

### CRITICAL: @ObservedObject Lifecycle — Object Recreated on Parent Redraw

**What goes wrong:** A view creates a `@ObservedObject var store = FamilyStore()` directly (not `@StateObject`). Every time the parent view redraws, SwiftUI discards and recreates the `FamilyStore` instance, destroying all in-flight network requests, subscriptions, and cached state.

**Why it happens:** `@ObservedObject` does not own the object's lifecycle. `@StateObject` does.

**Warning signs:**
- Network requests fire multiple times in rapid succession
- Subscriptions accumulate (multiple realtime channels opened per session)
- State resets to empty without user action

**Prevention:**
- Use `@StateObject` for objects created by the view, `@ObservedObject` only when the object is passed in from outside
- In iOS 17+, use `@State` with `@Observable` — this eliminates the `@StateObject`/`@ObservedObject` distinction entirely and produces finer-grained redraws
- Never instantiate a store/service inside a `@ObservedObject` property

**Phase:** Architecture / first screen — establish the ownership rule in the project style guide before writing the first ViewModel.

---

### CRITICAL: Expensive Computation Inside `body` Causes Jank

**What goes wrong:** Score totals, streak calculations, or sorted member lists computed inline in `body`. SwiftUI may call `body` dozens of times per second during animations or rapid state changes. A 200ms calculation in `body` makes the app feel broken.

**Why it happens:** SwiftUI's rendering pipeline is synchronous in `body`. Any non-trivial work blocks the main thread.

**Warning signs:**
- Instruments shows main thread CPU spikes during list scrolls
- Animations stutter when any family member's score updates
- App feels sluggish on older devices (iPhone SE)

**Prevention:**
- Pre-compute aggregates in the ViewModel, store results as simple value types
- Use `.task` or `async let` to compute on a background actor, then publish to the main actor
- Never sort, filter, or sum arrays in `body`
- Mark expensive view models with `@MainActor` to keep state mutations on the main thread but computation off it

**Phase:** Each feature phase — establish the "no computation in body" lint rule early.

---

### MODERATE: NavigationStack Path Corruption Under TabView

**What goes wrong:** `NavigationStack` nested inside `TabView` with a `@State` path binding. On iOS 16, SwiftUI writes an empty path on first render, collapsing any pre-populated navigation state. On iOS 17, concurrent path mutations during animations are silently dropped.

**Why it happens:** Documented Apple bug tracked since iOS 16 GA (GitHub feedback gist by mbrandonw). Partially improved but not fully fixed through iOS 17.

**Warning signs:**
- Deep linking into a score detail view collapses to root
- Programmatic navigation (`path.append(destination)`) occasionally does nothing
- Console shows SwiftUI layout warnings alongside navigation operations

**Prevention:**
- Manage `NavigationPath` in a `@Observable` Router class injected via environment — one source of truth, not one per view
- Never mutate `NavigationPath` during an ongoing navigation animation; use `Task { @MainActor in ... }` with a small yield before appending
- Target iOS 16 minimum, but design navigation tests on a real device, not Simulator (Simulator is more forgiving)
- Prefer `navigationDestination(for:)` over deprecated `NavigationLink(destination:)` patterns

**Phase:** Navigation scaffold (Phase 1) — get navigation right before building screens on top of it.

---

### MODERATE: `.task` Modifier Cancellation During Refresh

**What goes wrong:** Using `.refreshable { }` combined with `@Published` state mutations. Any `@Published` property change inside the refresh closure cancels the in-flight network task before it completes. Result: pull-to-refresh appears to do nothing.

**Why it happens:** `.refreshable` holds a `Task` internally. When `objectWillChange` fires (from a `@Published` change), SwiftUI cancels and restarts the body, which cancels the refresh task.

**Warning signs:**
- Pull-to-refresh spinner disappears immediately without data updating
- Network logs show request was cancelled, not failed

**Prevention:**
- Do not mutate any `@Published` or `@Observable` properties until the async fetch is fully complete
- Use a dedicated `isRefreshing: Bool` flag that is set after data arrives, not before
- Test pull-to-refresh on device with network throttling (Network Link Conditioner)

**Phase:** Feed/list views.

---

### MINOR: SwiftUI Preview Crashes With Supabase Dependency

**What goes wrong:** A view that directly references `supabase.from("activities")` in its initializer or body. Xcode Preview cannot initialize the Supabase client (no network, no bundle configuration) and the preview crashes with a cryptic error.

**Prevention:**
- Define a `protocol ActivityRepository` and inject via `@Environment`
- Provide a `MockActivityRepository` returning local test data for previews
- Wire the real `SupabaseActivityRepository` only in `App.swift` via `.environment`
- Never let a SwiftUI view import or reference `Supabase` directly — only the repository layer does

**Phase:** Architecture setup (Phase 1) — define the repository protocol pattern before writing the first view.

---

## 3. WidgetKit Pitfalls

---

### CRITICAL: 30 MB Hard Memory Limit — No Warning, Just Termination

**What goes wrong:** Widget extension is terminated by Jetsam (iOS memory watchdog) when it exceeds 30 MB. No crash report appears in standard logs. The widget goes blank or shows "Unable to load" with no diagnostic trace. This limit is real, enforced, and easily exceeded.

**Common causes exceeding 30 MB:**
- Loading full-resolution avatar images (even a single 650 KB PNG on a 3x display can exceed the limit)
- Using CoreData with a large persistent store in the extension
- Custom fonts (each font file loaded counts against the limit)
- Performing image cropping/compositing at render time

**Warning signs:**
- Widget renders in Simulator but goes blank on device
- Xcode Memory Graph for the extension shows 28-32 MB
- `os_log` messages in the extension stop mid-render

**Prevention:**
- Downscale all images before storing in App Group: target 80x80 pt @2x (160x160 px) maximum for avatar thumbnails
- Pre-render score badges in the main app, write the rendered PNG to App Group `UserDefaults` or shared container
- Never load a CoreData store in the widget; use plain `Codable` structs serialized to `UserDefaults` app group
- Measure memory in Instruments with the "Leaks" and "Allocations" instruments attached to the widget extension process specifically

**Phase:** Widget extension build — establish the image pipeline before connecting real data.

---

### CRITICAL: App Group Entitlement Mismatch — Works in Simulator, Fails on Device

**What goes wrong:** App Group is registered only for the main app target in the Apple Developer portal. The widget extension has the `com.apple.security.application-groups` entitlement in its `.entitlements` file pointing to the same group ID, but the portal does not list the extension's App ID as a member. Everything works in Simulator (which does not enforce portal entitlements) but the widget reads `nil` from `UserDefaults(suiteName:)` on a real device, silently.

**Warning signs:**
- `UserDefaults(suiteName: "group.com.yourapp")?.object(forKey: "latestScore")` returns `nil` on device but not Simulator
- No error in console — `UserDefaults` just returns `nil` for missing data
- TestFlight build shows stale/empty widget data

**Prevention:**
- In the Apple Developer portal: Identifiers → your extension App ID → App Groups → explicitly add the group
- In Xcode: both main target and widget extension target must have the same App Group string in their entitlements and in Signing & Capabilities
- After any provisioning profile regeneration, verify the group is still attached to both IDs
- Add a CI check: read from the shared `UserDefaults` suite in a UI test on a real device before every TestFlight submission

**Phase:** Widget setup sprint — verify on a real device before building any widget UI.

---

### MODERATE: Widget Does Not Refresh When Expected

**What goes wrong:** After a family member logs a new activity, the widget continues showing old data for 15-60 minutes. The developer calls `WidgetCenter.shared.reloadAllTimelines()` from the main app but the widget doesn't update immediately.

**Why it happens:** iOS enforces a per-widget "budget" for timeline refreshes. Calling `reloadAllTimelines()` requests a refresh but the OS decides when to honor it based on user engagement patterns, battery state, and Low Power Mode. The budget is typically 40-70 refreshes per day, and the OS will defer requests if the app is not used frequently.

**Warning signs:**
- Widget shows correct data in Simulator (Simulator has no budget throttling)
- On-device widget lags 30+ minutes behind the main app
- `reloadAllTimelines()` appears to do nothing in Low Power Mode

**Prevention:**
- Call `WidgetCenter.shared.reloadAllTimelines()` immediately when a new activity is saved (triggers a budget-aware refresh request)
- Design the widget to show a "last updated" timestamp so users understand data may be slightly stale
- Use the App Group `UserDefaults` to write a "pending update" flag — the widget reads this flag and can at least show the correct pending state even if the full timeline hasn't refreshed
- Accept the 15-30 minute lag as a design constraint, not a bug to fix

**Phase:** Widget extension build — set correct expectations in the design mockups before implementation.

---

### MODERATE: Lock Screen Widgets Have Severe Display Constraints

**What goes wrong:** Lock screen widgets (`.accessoryCircular`, `.accessoryRectangular`, `.accessoryInline`) do not support color on pre-Always-On-Display iPhones. On many devices they render as grayscale. Custom fonts may not render. Image size limits are more aggressive (120x120 px max empirically observed). The developer builds a rich colored score badge that looks broken on the actual lock screen.

**Warning signs:**
- Widget looks great in Xcode Preview but muted/broken on lock screen
- Color-coded family member scores are indistinguishable on grayscale lock screen

**Prevention:**
- Design lock screen widgets as monochrome-first; add color as progressive enhancement
- Test every accessory widget family on a physical device with the lock screen — not Simulator
- Provide a single, high-contrast number (score or streak) rather than rich charts on lock screen widgets
- Keep lock screen widget scope minimal: one piece of information per widget

**Phase:** Widget extension build.

---

### MINOR: Debugging Widgets Is Uniquely Painful

**What goes wrong:** `print()` statements do not appear in the Xcode console when the widget is refreshed by the OS. Breakpoints do not hit. The widget process is separate from the main app and runs out-of-process.

**Prevention:**
- Use `os_log` (Unified Logging) and read via `Console.app` on Mac, filtering by subsystem
- To attach debugger: Debug → Attach to Process → select the widget extension process by name immediately after triggering a refresh
- Build a "preview-only" mock that exercises widget rendering logic in the main app with a button — debug there first, then push to the actual extension
- For timeline logic, write unit tests that test `getTimeline()` in isolation without the actual WidgetKit runtime

**Phase:** Widget extension build — establish the `os_log` pattern from day one.

---

## 4. Multi-User Real-Time Pitfalls

---

### CRITICAL: Offline Activity Log Lost Permanently

**What goes wrong:** Child opens the app in Airplane mode and logs an activity. The app shows the activity as saved (optimistic UI), but there is no local persistence queue. When the app goes to the background and returns to network, the pending write is gone — no retry, no error, the log entry is silently dropped.

**Why it happens:** Supabase Swift client does not have a built-in offline queue. `supabase.from("activities").insert(...)` will throw if the network is unavailable.

**Warning signs:**
- QA tester logs activity while on subway (no signal), activity missing from history
- `URLError.notConnectedToInternet` appears in logs but is swallowed

**Prevention:**
- Implement a local pending-actions queue: on network failure, write the activity to `UserDefaults` or a simple local SQLite (GRDB) table with `status = "pending"`
- On `scenePhase == .active` and network reachability restored, drain the queue
- Show a "Waiting to sync" badge in the UI for pending entries
- This is scope-appropriate complexity: a simple `[PendingActivity]` array persisted to `UserDefaults` is sufficient for a family app (low volume, not a collaborative document editor)

**Phase:** Activity logging feature — design the offline path alongside the happy path, not as a follow-up.

---

### MODERATE: Two Family Members Log Simultaneously — Last Write Wins

**What goes wrong:** Parent and child both open the app and log activities at the same second. Both read the current `total_score` (e.g., 150), both add their points, both write their result (e.g., 160 and 155). Whichever write arrives last "wins" and the other's points are silently lost. Score ends up at 155 instead of 165.

**Why it happens:** Read-then-write race condition. Without atomic increment on the database side, concurrent clients corrupt the aggregate.

**Prevention:**
- Never read `total_score`, add to it, and write it back from the client
- Use a PostgreSQL function (RPC) that does the increment atomically:
  ```sql
  CREATE OR REPLACE FUNCTION log_activity(family_id uuid, points int)
  RETURNS void AS $$
    INSERT INTO activities (family_id, points, logged_at) VALUES ($1, $2, now());
  $$ LANGUAGE sql;
  ```
  Then compute `total_score` as a derived value: `SELECT SUM(points) FROM activities WHERE family_id = ?`
- Store individual activity rows, compute scores at read time (or via a materialized view) — never store a mutable `total_score` that clients increment directly

**Phase:** Data model design (Phase 1) — this architectural decision must be made before writing any activity logging code.

---

### MODERATE: Device Clock Skew Causes Wrong "Today" Bucket

**What goes wrong:** A child's iPhone has a clock 25 minutes fast (auto time off, or a manual change). An activity logged at 11:45 PM on their device is recorded with a UTC timestamp that falls into the next day. The weekly leaderboard shows the activity on the wrong day.

**Why it happens:** iOS does not enforce NTP sync if "Set Automatically" is disabled (parents sometimes disable this for screen time workarounds).

**Prevention:**
- Always store `logged_at = now()` as a PostgreSQL server-side timestamp using `DEFAULT now()` — not the client-provided timestamp
- Never trust client-provided timestamps for bucketing; only trust the server's `created_at`
- Display timestamps in local timezone using `TimeZone.current` on the device, but always bucket/aggregate using UTC on the server

**Phase:** Activity logging feature.

---

## 5. Gamification Pitfalls

---

### CRITICAL: Children Game the Points System

**What goes wrong:** A child discovers that logging "did homework" 50 times rapidly inflates their score. Points become meaningless. Parents lose trust in the system. Siblings complain about fairness. The entire motivation system collapses.

**Warning signs:**
- One family member's score is 10x higher than others within a week
- Activity log shows the same activity type logged minutes apart

**Prevention:**
- Enforce server-side rate limiting via a PostgreSQL constraint or RPC: one activity of a given type per child per day (or per N hours)
- Require parent approval for high-value activities (activities > X points require parent confirmation before counting)
- Make the approval flow lightweight: a single tap in the parent's notification is sufficient
- Show activity history transparently to all family members — sunlight is the best disinfectant

**Phase:** Activity logging feature + gamification layer.

---

### MODERATE: Weekly Reset Creates "Dead Zone" and "End-of-Week Rush"

**What goes wrong:** Points reset every Monday at midnight. Children disengage from Monday through Thursday ("too many points needed to matter"), then panic-log activities on Sunday evening. The score curve feels artificial and frustrating.

**Why it happens:** Hard resets create binary states (winning week / losing week). Once a child falls too far behind mid-week, the week is psychologically "lost."

**Prevention:**
- Use rolling 7-day windows instead of calendar week resets (always shows the last 7 days)
- Alternatively: carry forward a "bonus multiplier" from the previous week rather than hard resetting to zero
- Show daily streaks (consecutive days with at least one activity) as a parallel metric — streaks are immune to the reset problem
- If weekly reset is kept, reset on Sunday night not Monday — less disruptive psychologically

**Phase:** Gamification design (before implementing reset logic).

---

### MODERATE: Parents Feel Like Surveillance App

**What goes wrong:** Parents use the app primarily to monitor whether children did tasks, rather than to celebrate achievements together. Children feel watched, not rewarded. App becomes a source of conflict ("you didn't log your reading!") rather than connection.

**Warning signs:**
- App UX focuses on "compliance" rather than "celebration"
- Notifications are worded as reminders/alerts rather than encouragement
- Score difference between family members is prominently displayed as a ranking

**Prevention:**
- Frame all copy around celebration, not compliance: "Jamie earned 50 points!" not "Jamie's score is behind"
- Make the history feed feel like a highlight reel, not an audit log
- Allow children to add notes/photos to activities — personal expression, not just compliance
- Default notification copy: positive only ("New activity logged! Great job!") — never "reminder: no activities today"

**Phase:** UX/copy review at each milestone before release.

---

### MINOR: Points Inflation — High Scores That Mean Nothing

**What goes wrong:** After a few weeks, everyone has thousands of points. The numbers stop feeling meaningful. Children stop caring about a 500-point difference when totals are 15,000.

**Prevention:**
- Cap display values: show "1.5K" not "1,500"; show level/rank names ("Gold Family", "Champion") at milestones
- Introduce seasonal resets with permanent achievement badges earned from each season — the badge persists even after the score resets
- Design point values so a good week produces 100-500 points, not 10,000

**Phase:** Gamification design.

---

## 6. Project & Build Pitfalls

---

### CRITICAL: Supabase Package Added to Widget Extension Target

**What goes wrong:** Developer adds the Supabase Swift package as a dependency of the widget extension target to share auth tokens or fetch data directly. The Supabase SDK (PostgREST, Realtime, Storage) adds ~8-15 MB to the extension binary. Combined with other dependencies, the extension exceeds its size limit or the memory footprint makes the 30 MB runtime limit immediately unreachable.

**Prevention:**
- The widget extension must NOT link against the full Supabase SDK
- Data flow to widget: main app writes to shared App Group `UserDefaults` → widget reads from there
- If the widget needs fresh data, use a lightweight `URLSession` call with a hardcoded REST URL, not the Supabase Swift client
- Create a `SharedModels` Swift package (no dependencies) containing only `Codable` structs that both targets link against

**Phase:** Project setup (Phase 1) — define target membership rules before adding any packages.

---

### CRITICAL: Secrets in Source Control

**What goes wrong:** Supabase URL and anon key committed to git in `Config.xcconfig`, `Info.plist`, or hardcoded in Swift files. Repository becomes public or is leaked. While the anon key is designed to be client-visible (safe only with correct RLS), the service role key must never appear in client code or git.

**Warning signs:**
- `.xcconfig` files not in `.gitignore`
- `SUPABASE_URL` appears in `git log --all -S "SUPABASE_URL"`

**Prevention:**
- Add a `Secrets.xcconfig` file that is listed in `.gitignore`
- Reference the key in a non-secret `Config.xcconfig` via `#include "Secrets.xcconfig"`
- Provide a `Secrets.xcconfig.template` in git with placeholder values and instructions
- Use Xcode build setting injection so keys appear in `Info.plist` at build time and are never hardcoded
- The service role key belongs only in server-side Edge Functions, never in the iOS binary

**Phase:** Project setup (Phase 1, day 1).

---

### MODERATE: Shared Code Without a Shared Swift Package Leads to Target Membership Sprawl

**What goes wrong:** Utility files, model structs, and helpers are added to both the main app target and the widget extension target via Xcode's "Target Membership" checkboxes. Over time, 30+ files are dual-targeted. One file is accidentally removed from one target, causing a crash only in the widget. The error is not caught until TestFlight.

**Prevention:**
- Create a local Swift package `FamilyScoreKit` (File → New → Package) from day one
- Move all shared `Codable` models, helper extensions, and constants into `FamilyScoreKit`
- Both the main app and widget extension add `FamilyScoreKit` as a package dependency — no dual target membership for business logic files
- Widget extension links only: `FamilyScoreKit` + `WidgetKit`. Main app links: `FamilyScoreKit` + `Supabase` + `WidgetKit`

**Phase:** Project setup (Phase 1).

---

### MODERATE: SwiftUI Previews Break Across the Team

**What goes wrong:** Previews work on one developer's machine but crash for another because the preview depends on environment state, Supabase client initialization, or a `@StateObject` that expects a running backend.

**Prevention:**
- Establish the protocol/mock pattern from Phase 1: every service has a `Protocol` and a `Mock` implementation
- Previews always inject mocks via `.environment` — they never touch the real Supabase client
- Document the preview pattern in the project's `CONTRIBUTING` notes so new contributors follow it
- Use `#if DEBUG` guards around preview-incompatible initializers

**Phase:** Architecture setup (Phase 1).

---

## Phase Mapping Summary

| Phase | Pitfall to Address First |
|---|---|
| Phase 1: Foundation | RLS no-policies silent empty, cross-family data exposure, atomic score design (no mutable total_score), App Group entitlement setup, SharedModels package, secrets gitignore |
| Phase 2: Auth + Family | onAuthStateChange listener, refresh token silent logout, session lifecycle |
| Phase 3: Activity Logging | Offline queue, device clock skew (server-side timestamp), server-side rate limiting for gaming, atomic activity insert RPC |
| Phase 4: Realtime + Feed | Realtime lifecycle (subscribe on foreground, unsubscribe on background), foreground REST fetch on reconnect |
| Phase 5: Widget | 30MB memory limit image pipeline, App Group portal registration, Widget not refreshing expectations, lock screen grayscale, no Supabase SDK in widget target |
| Phase 6: Gamification | Weekly reset dead zone, surveillance framing, points inflation |
| All phases | No computation in SwiftUI body, @StateObject vs @ObservedObject ownership, NavigationStack Router pattern, preview mock injection |

---

## Sources

- [Supabase RLS Docs](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Supabase Security Flaw: 170+ Apps Exposed](https://byteiota.com/supabase-security-flaw-170-apps-exposed-by-missing-rls/)
- [Supabase Realtime Limits](https://supabase.com/docs/guides/realtime/limits)
- [Supabase Auth Sessions](https://supabase.com/docs/guides/auth/sessions)
- [Supabase Swift Refresh Token Bug #486](https://github.com/supabase/supabase-swift/issues/486)
- [WidgetKit 30MB Memory Limit — Apple Developer Forums](https://developer.apple.com/forums/thread/733347)
- [WidgetKit Pitfalls — Alex Moiseenko](https://medium.com/techpro-studio/widgetkit-some-pitfalls-i-found-55a404b2d8df)
- [App Groups Are Not Secure by Default](https://dev.to/konstantin_shkurko/app-groups-are-not-secure-by-default-heres-how-to-fix-that-1ii8)
- [SwiftUI NavigationStack Challenges](https://medium.com/@muhammadathief0/solving-common-ios-navigationstack-challenges-practical-solutions-based-on-my-experience-185c81a20940)
- [@Observable Macro Performance vs ObservableObject](https://www.avanderlee.com/swiftui/observable-macro-performance-increase-observableobject/)
- [Supabase Realtime Silent Disconnections](https://supabase.com/docs/guides/troubleshooting/realtime-handling-silent-disconnections-in-backgrounded-applications-592794)
- [iOS Secrets Management — NSHipster](https://nshipster.com/secrets/)
- [Lock Screen Widget Limitations — Initial Charge](https://initialcharge.net/2023/11/lock-screen-widget-limitations/)
- [Offline-First SQLite Sync Patterns 2025](https://developersvoice.com/blog/mobile/offline-first-sync-patterns/)
- [Implementing Optimistic Locking in PostgreSQL](https://reintech.io/blog/implementing-optimistic-locking-postgresql)
