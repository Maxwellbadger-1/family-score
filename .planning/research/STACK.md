# Technology Stack — Family Score

**Project:** Family Score (native iOS family activity tracking app)
**Researched:** 2026-05-15
**Overall confidence:** HIGH (core stack verified via official docs and Context7)

---

## Recommended Stack

### Core Framework

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Swift | 6.0 | Language | Required for Xcode 16 / App Store submissions from April 2025. Strict concurrency eliminates data-race crashes at compile time. |
| SwiftUI | iOS 16+ | UI framework | Declarative, first-class Apple support, required for WidgetKit. All chart/widget APIs are SwiftUI-native since iOS 16. |
| Xcode | 16+ | IDE | Mandatory for App Store submissions from April 2025. Includes iOS 18 SDK while still allowing iOS 16 deployment target. |
| iOS Deployment Target | 16.0 | Minimum OS | Lock Screen widgets (accessoryCircular, accessoryRectangular, accessoryInline) require iOS 16. This is the correct floor. |

**Confidence:** HIGH — Apple Developer documentation confirms iOS 18 SDK requirement for App Store submissions (April 2025), and Lock Screen widget families are documented as iOS 16+ only.

---

### Backend

| Technology | Version/Tier | Purpose | Why |
|------------|-------------|---------|-----|
| Supabase | Free tier | Backend-as-a-service | PostgreSQL + Realtime + Auth bundled. Free tier: 200 concurrent realtime connections (more than enough for 2-8 family members), 100 msg/sec, 100 channels per connection. |
| Supabase Auth | Built-in | Email/password authentication | Native Swift SDK support. PKCE flow is the default for iOS. No extra library needed. |
| Supabase Realtime | Built-in | Live activity feed updates | postgres_changes channel delivers INSERT/UPDATE/DELETE events in real time. Verified working with supabase-swift v2.x async/await. |
| Supabase PostgREST | Built-in | Database queries | REST API over PostgreSQL, called via supabase-swift `.from()` fluent builder. No separate networking layer needed. |
| Row Level Security (RLS) | Built-in | Data isolation per family | Enforced server-side in Postgres. Family members only see their own family_group rows. Required for safe Realtime subscriptions (events respect RLS policies). |

**Confidence:** HIGH — Supabase free tier limits confirmed from official docs. RLS + Realtime integration confirmed via official blog post and docs.

---

### Swift Package Dependencies

| Package | SPM URL | Current Version | Purpose | Why |
|---------|---------|----------------|---------|-----|
| supabase-swift | `https://github.com/supabase/supabase-swift` | 2.46.0 (April 2026) | Supabase client: DB, Auth, Realtime, Storage, Functions | Official Supabase SDK. v2.x uses async/await and AsyncStream natively. Single package includes all modules. |

**No other external packages are needed.** The rest is Apple frameworks.

**Confidence:** HIGH — Latest version confirmed from GitHub Releases page (v2.46.0, April 29, 2026).

---

### Apple Frameworks (Built-In — No Installation Required)

| Framework | Min iOS | Purpose | Notes |
|-----------|---------|---------|-------|
| SwiftUI | 13.0 | All UI | Use `.task {}` modifier for async data loading |
| WidgetKit | 14.0 (16.0 for Lock Screen) | Home Screen + Lock Screen widgets | Timeline-based, not network-capable directly |
| Swift Charts | 16.0 | Bar/line charts for time equity visualization | Native, declarative, zero dependencies. Replaces DGCharts entirely for iOS 16+. |
| AppIntents | 16.0 | Interactive widget buttons (iOS 17+ for buttons/toggles) | Log activity directly from widget via button tap (requires iOS 17 for interactivity) |
| SwiftData | 17.0 | Local persistence / offline cache | Optional: use if caching activity log locally before sync. Simpler than Core Data for SwiftUI. |
| UserDefaults (App Group) | All | Widget ↔ App shared simple data | Store latest score/summary for widget display without network. Required for all widget data. |
| Keychain (Shared Access Group) | All | Share auth token between app and widget extension | Supabase session token must be accessible to widget extension for any authenticated operations |
| Security (Keychain) | All | Secure token storage | Auth tokens stored in Keychain with shared access group entitlement |

**Confidence:** HIGH — All documented on developer.apple.com. Swift Charts confirmed iOS 16+. AppIntents buttons/toggles confirmed iOS 17+.

---

## Installation

```swift
// Package.swift or via Xcode File > Add Package Dependencies

// URL: https://github.com/supabase/supabase-swift
// From version: 2.0.0

// Add these products to your app target:
// - Supabase (includes Auth, Realtime, PostgREST, Functions, Storage)

// Widget Extension target only needs:
// - No Supabase dependency (widgets read from AppGroup UserDefaults, not Supabase directly)
```

```swift
// Supabase.swift — shared singleton
import Supabase

let supabase = SupabaseClient(
  supabaseURL: URL(string: "YOUR_SUPABASE_URL")!,
  supabaseKey: "YOUR_SUPABASE_ANON_KEY"
)
```

---

## Architecture: App ↔ Widget Data Flow

Widgets **cannot** make network requests directly. The correct pattern:

```
Main App (has Supabase client)
  → fetches/receives realtime data
  → writes summary to UserDefaults (App Group shared suite)
  → calls WidgetCenter.shared.reloadAllTimelines()

Widget Extension (no network)
  → reads from UserDefaults(suiteName: "group.com.yourapp.familyscore")
  → renders glanceable view from cached data
```

For auth token sharing (if widget extension ever needs Supabase auth):

```
Main App
  → stores session token in Keychain with shared Access Group entitlement

Widget Extension
  → reads from same Keychain Access Group
```

**Entitlement required on both targets:**
```
com.apple.security.application-groups = ["group.com.yourapp.familyscore"]
keychain-access-groups = ["$(AppIdentifierPrefix)com.yourapp.familyscore"]
```

---

## Realtime Subscription Pattern (SwiftUI + supabase-swift v2.x)

```swift
// In a SwiftUI ViewModel / @Observable class
func subscribeToActivities() async {
    let channel = supabase.channel("family_activities")

    // MUST register before subscribe()
    let changes = channel.postgresChange(
        AnyAction.self,
        schema: "public",
        table: "activities"
    )

    await channel.subscribe()

    for await change in changes {
        switch change {
        case .insert(let action):
            // append new activity to local array
            await MainActor.run { activities.append(decode(action.record)) }
        case .update(let action):
            // update existing entry
            break
        case .delete(let action):
            break
        }
    }
}
```

**Key constraint:** Callbacks must be registered BEFORE `channel.subscribe()` is called. Registering after will be silently rejected.

**RLS requirement for Realtime:** Tables must be added to the `supabase_realtime` publication AND have RLS policies that allow the authenticated user to SELECT rows. RLS events are enforced — users only receive change events for rows they can read.

---

## Authentication Approach

### Primary: Email + Password (PKCE flow — default in Swift)

```swift
// Sign up
try await supabase.auth.signUp(email: email, password: password)

// Sign in
try await supabase.auth.signInWithPassword(email: email, password: password)

// Observe auth state changes
for await (event, session) in supabase.auth.authStateChanges {
    // update app state
}
```

### Family Group Invite System

The `auth.admin.inviteUserByEmail()` method **requires the service role key** — it is an admin-only operation and cannot be called from a client app safely. 

**Recommended alternative for family invites:**

Use a **Supabase Edge Function** (Deno/TypeScript) that:
1. Receives a request from an authenticated family admin
2. Validates the caller is a family group admin
3. Uses the service role key server-side to call `inviteUserByEmail()`
4. Returns success/failure to the client

The Swift client calls this via:
```swift
try await supabase.functions.invoke("invite-family-member", options: .init(
    body: ["email": inviteEmail, "familyGroupId": familyGroupId]
))
```

Edge Functions are included in the Supabase Free tier (500,000 invocations/month).

**Confidence:** MEDIUM — Admin API requiring service role confirmed from official docs. Edge Function pattern is standard community practice; no official "family invite" tutorial exists.

---

## WidgetKit Specifics

### Widget Families for Family Score

| Family | iOS Req | Use Case |
|--------|---------|---------|
| `.systemSmall` | 14+ | Today's score summary per member |
| `.systemMedium` | 14+ | Mini leaderboard (2-3 members) |
| `.accessoryCircular` | 16+ | Lock Screen: current points ring |
| `.accessoryRectangular` | 16+ | Lock Screen: name + points + top activity |
| `.accessoryInline` | 16+ | Lock Screen: single-line leader summary |

### Interactive Widgets (iOS 17+)

Buttons and toggles using `AppIntent` are supported from iOS 17. For Family Score this enables a "Log Chore" quick-entry button directly on the widget. Implementation:

```swift
struct LogChoreIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Chore"
    
    func perform() async throws -> some IntentResult {
        // Write to AppGroup UserDefaults, main app syncs later
        // OR use URLSession in the intent (AppIntents CAN make network calls)
        return .result()
    }
}
```

**Important:** AppIntent `perform()` runs in the widget extension process and CAN use URLSession — this is different from the widget's Timeline view rendering. Use this for quick-entry logging.

### Timeline Update Strategy

```swift
struct ActivityTimelineProvider: TimelineProvider {
    func getTimeline(in context: Context, completion: @escaping (Timeline<ActivityEntry>) -> Void) {
        // Read from AppGroup UserDefaults
        let entry = ActivityEntry(date: .now, scores: loadFromAppGroup())
        // Refresh every 15 minutes max (OS may throttle further)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}
```

The main app triggers widget refresh after each realtime update:
```swift
WidgetCenter.shared.reloadAllTimelines()
```

---

## Supabase Free Tier — Sufficiency Assessment

| Resource | Free Limit | Family Score Need | Verdict |
|----------|-----------|------------------|---------|
| Realtime connections | 200 concurrent | 2-8 members | Sufficient (100x headroom) |
| Messages/sec | 100 | < 1 per activity log | Sufficient |
| Channels per connection | 100 | 1-2 per user | Sufficient |
| Database size | 500 MB | Activity logs, scores | Sufficient for years |
| Auth users | Unlimited | 2-8 | Sufficient |
| Edge Function invocations | 500K/month | Family invites | Sufficient |
| Row Level Security | Included | Required for family isolation | Sufficient |

**Verdict:** Free tier is adequate indefinitely for a family app with 2-8 members.

**Confidence:** HIGH — Limits confirmed from official Supabase docs and pricing page.

---

## Swift 6 Concurrency Notes

Swift 6 (bundled with Xcode 16, required for App Store from April 2025) enforces strict concurrency checking at compile time. Key implications:

- Mark ViewModels/ObservableObjects with `@MainActor` — required in Swift 6 for `@StateObject` / `@Observable`
- Use `await MainActor.run { }` for UI updates from background async tasks (e.g., Realtime callbacks)
- supabase-swift v2.x is designed for Swift concurrency — async/await and AsyncStream are native
- Replace any `DispatchQueue.main.async {}` with `await MainActor.run {}`

---

## Alternatives Considered and Rejected

| Category | Recommended | Rejected | Why Rejected |
|----------|-------------|----------|-------------|
| Backend | Supabase | Firebase | No native SQL, no free-tier Realtime at this scale, vendor lock-in, weaker Postgres story |
| Backend | Supabase | CloudKit | Apple-only, poor query capabilities, no web dashboard, complex conflict resolution |
| Backend | Supabase | Custom REST API | Too much infra to build/maintain for a family app |
| Charts | Swift Charts (native) | DGCharts (ChartsOrg/Charts) | DGCharts has sparse commits in 2025, Swift Charts is iOS 16+ native with full SwiftUI integration, zero dependencies |
| Charts | Swift Charts (native) | SwiftUICharts | Unmaintained community library, no need when Apple provides first-party solution |
| Local persistence | SwiftData | Core Data | Core Data requires UIKit-era boilerplate; SwiftData is SwiftUI-native. Only use Core Data if iOS 16 support needed for local cache (SwiftData is iOS 17+). Use plain UserDefaults for widget data — no persistence framework needed in widget extension. |
| Language | Swift 6 | Objective-C | Not relevant; no legacy code |
| Platform | Native SwiftUI | React Native / Flutter | WidgetKit requires native; cross-platform frameworks cannot build WidgetKit extensions |
| Auth invite | Server-side Edge Function | Client-side admin API | `inviteUserByEmail()` requires service role key which must never be in client app code |
| Realtime strategy | postgres_changes | Broadcast | postgres_changes is simpler for this use case (activity logs are DB writes; broadcast is for ephemeral events). Both are viable; postgres_changes gives automatic persistence. |

---

## Sources

- Supabase Swift releases: https://github.com/supabase/supabase-swift/releases (verified v2.46.0, April 2026)
- Supabase Swift quickstart: https://supabase.com/docs/guides/getting-started/quickstarts/ios-swiftui
- Supabase Swift channel subscribe: https://supabase.com/docs/reference/swift/subscribe
- Supabase Swift invite API: https://supabase.com/docs/reference/swift/auth-admin-inviteuserbyemail
- Supabase Realtime limits: https://supabase.com/docs/guides/realtime/limits
- Supabase Postgres Changes: https://supabase.com/docs/guides/realtime/postgres-changes
- Supabase Realtime auth/RLS: https://supabase.com/docs/guides/realtime/authorization
- Swift Charts: https://developer.apple.com/documentation/charts
- WidgetKit: https://developer.apple.com/documentation/widgetkit
- App Store iOS 18 SDK requirement: https://dev.to/raphacmartin/dont-panic-what-apples-ios-18-sdk-update-really-means-for-your-app-5cj2
- iOS Keychain sharing across extensions: https://medium.com/@thomsmed/share-authentication-state-across-your-apps-app-clips-and-widgets-ios-e7e7f24e5525
- Lock Screen widgets SwiftUI: https://swiftwithmajid.com/2022/08/30/lock-screen-widgets-in-swiftui/
- Interactive widgets iOS 17 AppIntents: https://www.createwithswift.com/creating-interactive-widget-swiftui/
- Swift 6 concurrency: https://developer.apple.com/documentation/swift/adoptingswift6
