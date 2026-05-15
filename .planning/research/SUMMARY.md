# Research Summary - Family Score

**Synthesized:** 2026-05-15
**Sources:** STACK.md, FEATURES.md, ARCHITECTURE.md, PITFALLS.md
**Overall Confidence:** HIGH

---

## Executive Summary

Family Score is a native iOS family activity tracking app that fills a documented gap: no existing app tracks time equity across all life domains (chores, errands, hobby hours, care work, school) in a single unified view. The competitive landscape (OurHome, Sweepy, Tody, Habitica, Chorly) confirms strong demand for gamified family tracking, but every incumbent is too narrow (cleaning only), too complex (RPG systems), or neglects the iOS widget surface. Family Score wins as a time-equity visualizer, not a chore app, built around Apple Health-style rings and a first-class lock screen widget.

The technical approach is unambiguous: Swift 6 + SwiftUI + Supabase free tier, with no third-party libraries beyond supabase-swift v2.x and Apple built-in frameworks (WidgetKit, Swift Charts, AppIntents). MVVM with @Observable service singletons, one Supabase client for the main app, widget data via App Group UserDefaults only. Fully sufficient for 2-8 family members on the free tier indefinitely.

The primary risk is UX tone and scope, not technical difficulty. Hard streak resets, aggressive paywalls, and surveillance-framing are the documented abandonment causes across every competitor. The design must lead with celebration over compliance and rolling 7-day windows over hard resets. All gamification mechanics must be locked before any code is written.

---

## 1. Recommended Tech Stack

| Layer | Technology | Version | Decision |
|-------|-----------|---------|----------|
| Language | Swift | 6.0 | Mandatory. App Store requires Swift 6 / Xcode 16 from April 2025. |
| UI | SwiftUI | iOS 16+ | Required for WidgetKit lock screen families and Swift Charts. |
| IDE | Xcode | 16+ | Mandatory for App Store submissions. |
| Deployment target | iOS | 16.0 | Lock Screen widgets require iOS 16 minimum. |
| Backend | Supabase | Free tier | PostgreSQL + Realtime + Auth + Edge Functions. Free tier sufficient for 2-8 members indefinitely. |
| Supabase SDK | supabase-swift | 2.46.0 | Only external package needed. Uses async/await natively. |
| Charts | Swift Charts | Built-in (iOS 16+) | Apple-native, zero dependencies. Replaces DGCharts. |
| Local persistence (v1) | UserDefaults (App Group) | Built-in | Widget data only. No local DB in v1. |
| Local persistence (v2+) | SwiftData | iOS 17+ | Defer until offline-first demand is confirmed. |
| Widgets | WidgetKit + AppIntents | Built-in | Lock Screen + Home Screen. Interactive buttons require iOS 17. |

**Rejected alternatives:** Firebase (no native SQL, weaker Realtime), CloudKit (Apple-only, poor queries), React Native / Flutter (cannot build WidgetKit extensions), DGCharts (unnecessary when Swift Charts is native), TCA architecture (over-engineered for this scope).

---

## 2. Table Stakes Features (Must Ship in v1 MVP)

Eight features are the minimum viable product. Missing any one makes the app feel incomplete against direct competitors.

| Priority | Feature | Notes |
|----------|---------|-------|
| 1 | Activity logging with duration and category | Under 3 taps. Speed is the UX. |
| 2 | Per-person profiles (up to 6 family members) | Roles: admin, adult, child. |
| 3 | Time-based point system (minutes to points) | Points pre-computed at insert. Never a mutable total on the client. |
| 4 | Ring visualization per person per day | Apple Health-style. One color per member throughout the app. |
| 5 | Cross-device real-time sync (Supabase Realtime) | Postgres Changes on activity_entries. Not Broadcast. |
| 6 | Lock screen widget (accessoryCircular) | Single ring for one member. Monochrome-first design. |
| 7 | Today view, family status at a glance | Home screen of the app. Glanceable in under 2 seconds. |
| 8 | History log, 30 days filterable by person | Answering who did what last week resolves a documented conflict trigger. |

**Post-MVP (v1.1):** Time equity dashboard, Home Screen widget (family row), streak system with grace periods, recurring activities and rotation, child-assisted UI mode, monthly period review.

**Defer to Phase 3+:** Reward redemption, photo proof for tasks, fairness gap alerts, progressive teen/adult interface, parental approval workflow.

---

## 3. Key Architectural Decisions

### Data Model
- Multi-tenant boundary: families table. Every data table has a family_id column with an RLS policy enforcing membership.
- Source of truth: individual activity_entries rows. Score totals derived via DB trigger into weekly_summaries. Never mutable client-writable aggregates.
- Points pre-computed at INSERT time (duration_minutes * category.point_weight). Weight changes only affect future entries.
- All timestamps use server-side DEFAULT now(). Never trust client-provided timestamps for date bucketing.

### iOS Architecture
- Pattern: MVVM + @Observable + service layer singletons injected via SwiftUI Environment.
- One SupabaseClient instance for the full app lifecycle. Widget extension has NO Supabase dependency.
- Offline strategy for v1: optimistic UI with error rollback (no local DB). Re-evaluate with SwiftData or PowerSync for v2.
- Navigation: @Observable Router injected via Environment. Never use @ObservedObject to own a router inside a view.

### Widget Architecture
- Widget extension reads ONLY from App Group UserDefaults. No Supabase SDK or URLSession calls in v1.
- Write path: Supabase Realtime event -> ActivityService -> WidgetDataWriter -> App Group UserDefaults -> WidgetCenter.shared.reloadAllTimelines().
- Widget timeline: 1-hour scheduled fallback. Real updates triggered by the main app.
- Shared models in a local FamilyScoreKit Swift package. No dual target membership for model files.

### Security
- RLS on every table from day one. Every policy joins on family_id and membership. Never USING (true).
- Supabase anon key in Secrets.xcconfig (gitignored). Service role key only in server-side Edge Functions.
- Keychain items use kSecAttrAccessibleAfterFirstUnlock so widgets work after device reboot.

### Family Invite Flow
- Token-based: family_invites table with 7-day expiry. Join via accept_invite PostgreSQL RPC (security definer).
- Deep link: familyscore://invite?token=abc123 handled via .onOpenURL.
- Child accounts v1: parent creates a proxy email account. No COPPA consent flow needed in v1.

---

## 4. Top 5 Pitfalls to Avoid

### Pitfall 1: RLS Enabled Without Policies (CRITICAL)
Enabling RLS with no policies returns silent empty results -- no error, no 403, just an empty array. Every table needs SELECT, INSERT, and UPDATE policies at creation time. Test from the Swift client, not the Supabase SQL editor (which bypasses RLS).

### Pitfall 2: App Group Entitlement Mismatch (CRITICAL)
Works in Simulator, silently fails on device. Both the main app App ID AND the widget extension App ID must be in the Apple Developer portal under the same App Group. UserDefaults(suiteName:) returns nil silently when the portal registration is missing. Verify on a real device before building widget UI.

### Pitfall 3: Widget Extension 30 MB Memory Limit (CRITICAL)
No OS warning -- the widget goes blank when terminated by Jetsam. Causes: full-res avatar images, CoreData in the extension, custom fonts. Fix: downscale images to 80x80pt @2x before writing to App Group; use plain Codable structs in UserDefaults; never load CoreData in the widget extension.

### Pitfall 4: Mutable Total Score Client-Side (CRITICAL, data corruption)
Concurrent writes with read-then-write produce a race condition and silently lost points. Fix: store individual activity_entries, compute totals server-side via DB trigger into weekly_summaries. Never store a total_score column that clients increment.

### Pitfall 5: Realtime Silent Disconnection in iOS Background (MODERATE, high user impact)
WebSocket heartbeat stops within 30-60 seconds of backgrounding. Events stop silently. On scenePhase == .active, re-fetch from REST first then re-subscribe. Disconnect Realtime on background. Build this lifecycle management before any real-time UI.

**Also high-priority:**
- Use @StateObject or @State+@Observable. @ObservedObject must never own a service instance.
- Never link the Supabase SDK to the widget extension target (adds 8-15 MB, makes 30 MB limit unreachable).
- Secrets.xcconfig in .gitignore from day one.
- Enforce server-side activity rate-limiting from Phase 3 or children will game the points system.
- Use rolling 7-day score windows. Calendar hard resets cause mid-week disengagement and Sunday panic-logging.

---

## 5. Suggested Build Order / Phase Structure

### Phase 1: Foundation (blocker for everything)
**Delivers:** Authenticated app shell with no user-visible features.
**Work:** Supabase project + schema + RLS policies for all tables; SupabaseClient singleton; AuthService; sign-up/sign-in/sign-out UI; onAuthStateChange listener; DependencyContainer + Environment injection; FamilyScoreKit local package; Secrets.xcconfig gitignored; App Group entitlement on both targets.
**Must avoid:** RLS without policies, secrets in git, Supabase SDK in widget target, mutable aggregate score design.
**Research flag:** Standard patterns. No further research needed.

### Phase 2: Family Core
**Delivers:** Family creation and join flow. Members can see each other.
**Work:** Family creation; invite token generation + accept_invite RPC; deep link handling; FamilyService + CategoryService; default category seeding (household, hobby, errands, work, care); role system (admin / adult / child).
**Must avoid:** Cross-family RLS exposure. Two-account QA test required before shipping.
**Research flag:** Standard patterns. No further research needed.

### Phase 3: Activity Logging + Dashboard
**Delivers:** Core product loop. Log activities, see family rings and scores.
**Work:** ActivityService with optimistic insert + error rollback; offline pending queue (UserDefaults array); activity log screen (under 3 taps); DB trigger for weekly_summaries; ring visualization per member; today view; history log (30 days).
**Must avoid:** Trusting client timestamps; missing rate-limiting (children gaming points); missing offline queue.
**Research flag:** SwiftUI ring performance with 6 simultaneous animated rings. Verify before layout is locked.

### Phase 4: Real-time + Widgets
**Delivers:** Live cross-device updates. Lock screen widget live in production.
**Work:** Supabase Realtime in ActivityService; reconnection lifecycle (scenePhase observer + foreground re-fetch); WidgetDataWriter + App Group writes; WidgetKit extension with FamilyScoreProvider; lock screen widget UI (accessoryCircular, monochrome-first); WidgetCenter.shared.reloadAllTimelines() trigger chain.
**Must avoid:** Multiple channels per view (singleton only); widget memory limit; color assumption on lock screen.
**Research flag:** WidgetKit APNs push for widget updates when main app is not running. Verify Edge Function + APNs before implementing.

### Phase 5: Settings + Polish
**Delivers:** Admin controls, child-safe UI, push notifications, App Store readiness.
**Work:** Category management UI (admin only); role-based UI gating; push notifications via Edge Function; point history view; App Store checklist.
**Must avoid:** Surveillance framing in copy; hard streak resets; aggressive paywalls.
**Research flag:** Standard patterns. No further research needed.

### Phase 6: Differentiators (post-launch)
**Delivers:** Time equity dashboard, home screen widget, streaks, auto-rotation -- features that drive word-of-mouth.
**Work:** Time equity dashboard (duty vs. free time ratio, fairness gap alerts); home screen widget (medium family row); streak system with grace periods (rolling 7-day); recurring activities + rotation; monthly period review.
**Must avoid:** Points inflation (seasonal resets, capped display values); hard weekly reset dead zone.
**Research flag:** Time equity UX for adult couples. No well-documented pattern for presenting fairness data without triggering conflict. User testing required before shipping the equity dashboard.

---

## 6. Open Questions That Need Decisions Before Building

| Question | Stakes | Recommendation |
|----------|--------|----------------|
| Monetization model? | Aggressive paywalls are the #1 complaint across Sweepy, Tody, Chorsee. | Generous free tier. Charge for advanced analytics or multi-family support. Decide before App Store submission planning. |
| Rolling 7-day or calendar week for scores? | Affects DB schema and all summary UI. Changing post-launch requires a migration. | Rolling 7-day. Decide in Phase 3 before writing summary queries. |
| Three rings or one aggregate ring per person? | Apple uses 3 rings (Move/Exercise/Stand). Family Score could use Duty/Free/Balance or a single score ring. | Decide before Phase 3 ring work begins. Post-launch changes break the mental model. |
| Point scale (1 pt/min vs. 10 pts/min)? | Determines whether a good week produces 100 or 10,000 points. Inflation kills motivation. | Target 100-500 points per productive week. Set in Phase 3 as a schema constant. |
| Children on independent devices? | Determines COPPA/GDPR-K consent flow requirements. | Parent-managed accounts for v1 (no consent flow). Revisit before Phase 6. |
| Lock screen widget: one member or whole family? | accessoryCircular fits one ring. Family summary needs accessoryRectangular or Home Screen widget. | Decide before Phase 4 UI design begins. |
| Invite: token only, or also email invite? | Email invite needs an Edge Function with service role key. | Token-only for v1. Add email invite via Edge Function in Phase 5+. |

---

## 7. Confidence Assessment

| Area | Confidence | Basis |
|------|-----------|-------|
| Tech stack | HIGH | Official Apple and Supabase docs verified. supabase-swift v2.46.0 confirmed from GitHub (April 2026). |
| Feature landscape | HIGH | 13 competitor apps analyzed. App Store reviews cited. UX psychology research sourced. |
| Architecture patterns | HIGH | Supabase Swift SDK docs, WidgetKit official docs, production RLS patterns all verified. |
| Pitfalls | HIGH | All findings verified against official docs, GitHub issues, or Apple Developer Forums. |
| Gamification design | MEDIUM | Competitive case studies solid. No direct data on time-equity UX with adult couples. |
| COPPA compliance | LOW | Parent-managed accounts recommended as workaround. Actual legal requirements not researched. |
| App Store review criteria | MEDIUM | iOS 18 SDK requirement confirmed. WidgetKit-specific criteria not researched. |

**Gaps to address during planning:**
- Legal/compliance review for child accounts if v2 requires independent child devices
- Monetization model decision (blocks all App Store submission planning)
- User research on how adult couples respond to equity data (risk of surfacing relationship tension)

---

## Sources (Aggregated)

- Supabase Swift SDK: https://supabase.com/docs/reference/swift/introduction
- supabase-swift releases: https://github.com/supabase/supabase-swift/releases
- Supabase Realtime limits: https://supabase.com/docs/guides/realtime/limits
- Supabase RLS docs: https://supabase.com/docs/guides/database/postgres/row-level-security
- Supabase Realtime disconnections: https://supabase.com/docs/guides/troubleshooting/realtime-handling-silent-disconnections-in-backgrounded-applications-592794
- Supabase refresh token bug: https://github.com/supabase/supabase-swift/issues/486
- WidgetKit docs: https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date
- WidgetKit 30MB limit: https://developer.apple.com/forums/thread/733347
- Swift Charts: https://developer.apple.com/documentation/charts
- AppIntents interactive widgets: https://www.createwithswift.com/creating-interactive-widget-swiftui/
- Lock Screen widget limitations: https://initialcharge.net/2023/11/lock-screen-widget-limitations/
- Apple Activity Rings HIG: https://developer.apple.com/design/human-interface-guidelines/activity-rings
- Habitica gamification case study: https://trophy.so/blog/habitica-gamification-case-study
- Streak UX psychology: https://www.smashingmagazine.com/2026/02/designing-streak-system-ux-psychology/
- OurHome App Store reviews: https://apps.apple.com/us/app/ourhome-by-elusios/id6753957205
- Sweepy review: https://www.tidied.app/blog/sweepy-app-review
- Tody review: https://www.tidied.app/blog/tody-app-review
- Best chore apps 2026: https://gethomsy.com/blog/comparisons/best-chore-chart-apps-2026
- Swift 6 concurrency: https://developer.apple.com/documentation/swift/adoptingswift6
- Sharing data with a widget: https://useyourloaf.com/blog/sharing-data-with-a-widget/
- Modern iOS architecture 2025: https://medium.com/@csmax/the-ultimate-guide-to-modern-ios-architecture-in-2025-9f0d5fdc892f