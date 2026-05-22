# Roadmap: Family Score

## Overview

Family Score is built in six phases that follow a strict dependency order dictated by iOS and Supabase architecture constraints. Phase 1 lays the non-negotiable technical foundation (Xcode multi-target project, App Group, Supabase schema with RLS). Phase 2 delivers authentication. Phase 3 brings the family group system. Phase 4 delivers the core product loop — activity logging, the ring dashboard, and the score engine. Phase 5 adds live cross-device sync and all widgets. Phase 6 closes out with admin settings, child-safe UI modes, and App Store polish.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation** - Xcode project, App Group, Supabase schema + RLS, FamilyScoreKit package — no user-visible features, blocks everything else *(completed 2026-05-15)*
- [ ] **Phase 2: Authentication** - Sign-up, Sign in with Apple, persistent sessions, sign-out
- [ ] **Phase 3: Family Core** - Family creation, invite flow, member profiles, child account setup
- [ ] **Phase 4: Activity Logging & Dashboard** - Core product loop: log activities, ring visualizations, score engine, dashboard views
- [ ] **Phase 5: Real-time & Widgets** - Live Supabase Realtime sync, push notifications, all WidgetKit surfaces
- [ ] **Phase 6: Settings & Polish** - Category management, point weights, child UI modes, App Store readiness

## Phase Details

### Phase 1: Foundation
**Goal**: A buildable, deployable Xcode project shell that connects to Supabase and is structurally correct for all future work — App Group entitlements provisioned on device, schema and RLS live, secrets out of git
**Depends on**: Nothing (first phase)
**Requirements**: *(no user-visible requirements — pure enabling infrastructure)*
**Success Criteria** (what must be TRUE):
  1. ✅ App builds successfully in CI (GitHub Actions, iOS Simulator) with the main app target and Widget Extension target both present *(Hinweis: "runs on a real device" entfällt — Windows-only, kein Mac verfügbar; CI-Build ist ausreichend für Phase 1)*
  2. ⚠️ App Group container auf physischem Gerät verifiziert — **ausstehend** (benötigt Sideloading via Sideloadly oder Mac; wird in Phase 5 gemeinsam mit Widget-Tests nachgeholt)
  3. ✅ Supabase schema is live with all tables (families, family_members, activity_entries, category_config, family_invites, weekly_summaries) and every table has RLS enabled with real policies — verified by a Swift client call, not the Supabase dashboard
  4. ✅ Secrets.xcconfig is gitignored and the Supabase anon key is absent from every committed file
  5. ✅ FamilyScoreKit local Swift package exists and is linked to the main app target only (widget extension has no Supabase SDK dependency)
**Plans**: 3 plans
Plans:
- [x] 01-PLAN-01.md — Xcode-Projektstruktur: zwei Targets (App + Widget Extension), App Group Entitlements, xcconfig-Secrets-System
- [x] 01-PLAN-02.md — FamilyScoreKit lokales Swift Package: WidgetData (Sendable), appGroupIdentifier, keine externen Abhaengigkeiten
- [x] 01-PLAN-03.md — Supabase Integration: supabase-swift SPM, SupabaseClient Singleton, SQL-Migration (DDL + RLS + Trigger), Schema Push, SC-3/SC-4 Verifikation

### Phase 2: Authentication
**Goal**: Users can create an account and stay securely logged in across restarts, or sign in with Apple, and sign out at will
**Depends on**: Phase 1
**Requirements**: AUTH-01, AUTH-02, AUTH-03, AUTH-04
**Success Criteria** (what must be TRUE):
  1. User can register with email + password and immediately land in the app
  2. User can sign in with Apple (including the Edge Function invite path so the service role key never lives in the client)
  3. User remains logged in after force-quitting and reopening the app
  4. User can sign out from any screen and is returned to the login screen with no residual data visible
**Plans**: 3 plans
Plans:
- [x] 02-01-PLAN.md — Wave 0: XCTest-Infrastruktur (FamilyScoreTests-Target, AppState.swift, AuthServiceTests-Stubs, MockAuthService + AuthServiceProtocol) *(completed 2026-05-16)*
- [x] 02-02-PLAN.md — Wave 1: AuthService (ObservableObject, authStateChanges), RootView (AppState-Routing), LoginView + RegisterView + AuthFlowView *(completed 2026-05-16)*
- [ ] 02-03-PLAN.md — Wave 2: Sign in with Apple (Nonce-Fluss, ASAuthorizationController), FamilyScoreApp.swift Integration, Appetize-Checkpoint *(Tasks 1+2 complete 2026-05-16 — Task 3: E-Mail-Auth via Appetize.io verifizieren; Sign-in-with-Apple-Flow nur auf physischem Gerät vollständig testbar)*

### Phase 3: Family Core
**Goal**: Users can form or join a family group, see all members, manage roles, and set up child profiles — family isolation enforced by RLS
**Depends on**: Phase 2
**Requirements**: FAM-01, FAM-02, FAM-03, FAM-04, FAM-05, KID-01, SETTINGS-03
**Success Criteria** (what must be TRUE):
  1. First user can create a family group and is automatically granted the Admin role
  2. Admin can generate an invite token; a second user on a separate device can join the family using that token and immediately see the family
  3. Admin can remove a member and that member can no longer see the family's data
  4. Admin can change any member's role (Admin / Adult / Child-simplified)
  5. Each member has a visible profile with name and avatar color; parent-managed child profiles appear in the member list without requiring a separate device login
**Plans**: 4 plans
Plans:
- [x] 03-01-PLAN.md — Wave 0: SQL-Migrationsdatei (child_profiles DDL, 4 SECURITY DEFINER RPCs, RLS-Policies), FamilyService-Test-Infrastruktur (FamilyServiceProtocol, MockFamilyService, 10 Teststubs) *(completed 2026-05-17)*
- [x] 03-02-PLAN.md — Wave 1: FamilyService (ObservableObject, 10 Protocol-Methoden, 4 RPCs) + AuthService.refreshFamilyStatus() *(completed 2026-05-17)*
- [x] 03-03-PLAN.md — Wave 2: SwiftUI Family-Views (FamilyOnboardingView, CreateFamilyView, JoinFamilyView, MemberListView, InviteSheet, RolePickerSheet, AddChildView) *(7 Views 2026-05-17 — iOS 16 @EnvironmentObject, refreshFamilyStatus() verknuepft, Admin-Actions)*
- [ ] 03-04-PLAN.md — Wave 3: App-Verdrahtung (RootView + FamilyScoreApp), Test-Suite gruen, Appetize-Checkpoint (5 Success Criteria via Appetize.io; FAM-02 Invite-Flow braucht zwei Appetize-Sessions) *(Tasks 1+2 abgeschlossen 2026-05-17 — Task 3: checkpoint:human-verify ausstehend)*

### Phase 4: Activity Logging & Dashboard
**Goal**: Family members can log activities and see time and score data for themselves and the whole family — the complete core product loop works end to end
**Depends on**: Phase 3
**Requirements**: LOG-01, LOG-02, LOG-03, LOG-04, LOG-05, LOG-06, DASH-01, DASH-02, DASH-03, DASH-04, DASH-05, SCORE-01, SCORE-02, SCORE-03
**Success Criteria** (what must be TRUE):
  1. User can log an activity with a live timer (Start/Stop) or retroactively with category + duration, in under 3 taps from the home screen
  2. User can log an activity on behalf of a child profile; the entry appears under the child's data
  3. User can delete their own entries; Admin can delete any entry
  4. Home screen shows personal Apple Health-style rings (Duty, Leisure, Score) that reflect today's logged activities
  5. Family comparison view shows all members side-by-side with today's duty hours, leisure hours, and score — derived from activity_entries via server-side aggregation, never a mutable total column
  6. Week summary view shows each member's totals for the current week and names the weekly leader
**Plans**: 4 plans
Plans:
- [x] 04-01-PLAN.md — Wave 0: ActivityServiceProtocol + alle Modelle, MockActivityService, XCTest-Stubs (ActivityServiceTests + RingProgressTests), SQL-Migration 20260516_phase4_rpcs.sql (4 RPCs), [BLOCKING] supabase db push *(completed 2026-05-22)*
- [x] 04-02-PLAN.md — Wave 1: ActivityService (ObservableObject, CRUD + Timer + Optimistic UI + RPC-Calls), ActivityEntry-Stub
- [ ] 04-03-PLAN.md — Wave 2: Dashboard-UI (SingleRingView, RingClusterView, DashboardView, WeekSummaryView) + ActivityLogSheet
- [ ] 04-04-PLAN.md — Wave 3: ActivityListView + ActivityRowView, App-Verdrahtung (TabView, @StateObject Injection), Test-Suite gruen, Appetize-Checkpoint

### Phase 5: Real-time & Widgets
**Goal**: Activity logged on one device appears on every other family device within seconds; Lock Screen and Home Screen widgets display live data
**Testing-Hinweis**: Widget-Tests (Lock Screen, App Group) erfordern physisches iPhone — Sideloadly auf Windows installiert die CI-`.ipa` direkt aufs Gerät (kein Mac nötig). App Group SC-2 aus Phase 1 wird hier nachgeholt.
**Depends on**: Phase 4
**Requirements**: SYNC-01, SYNC-02, SYNC-03, WIDGET-01, WIDGET-02, WIDGET-03, WIDGET-04, WIDGET-05
**Success Criteria** (what must be TRUE):
  1. When a family member logs an activity on their device, the rings and activity feed on a second family device update without any manual refresh (Supabase Realtime, reconnected on every scenePhase .active transition)
  2. Lock Screen accessoryCircular widget shows the current user's today score ring and updates when the main app processes a Realtime event
  3. Lock Screen accessoryRectangular widget lets the user tap a category to open a quick-entry sheet in the main app
  4. Home Screen large widget shows the family score ranking for all members
  5. Home Screen large Quick-Entry widget shows category buttons that start an activity via AppIntent (iOS 17+ interactive behavior)
  6. Home Screen medium widget shows the current user's three personal rings
  7. User receives an opt-in push notification when any family member logs an activity (delivered via Supabase Edge Function)
**Plans**: 4 plans
Plans:
- [ ] 05-01-PLAN.md — Wave 0: WidgetData.swift erweitern (5 neue Felder), FamilyScoreEntry um data: WidgetData, URL-Scheme project.yml, Test-Infrastruktur (MockRealtimeService + 5 Testklassen), App Group + Realtime-Publikation Checkpoint
- [ ] 05-02-PLAN.md — Wave 1: RealtimeService (XCTest-Guard, Channel-Lifecycle, scenePhase), WidgetDataWriter (Singleton, Debounce), FamilyScoreProvider (echter Provider), WIDGET-01..03+05 Widget-Views, FamilyScoreApp scenePhase-Handler
- [ ] 05-03-PLAN.md — Wave 2: LogActivityIntent in FamilyScoreKit, QuickEntryWidget WIDGET-04 (#available iOS 17+), drainPendingWidgetLogs(), Geraet-Checkpoint alle 5 Widgets
- [ ] 05-04-PLAN.md — Wave 3 (Spike): device_push_tokens Migration, [BLOCKING] supabase db push, NotificationService, Edge Function push-notification, Database Webhook, SYNC-03 Geraet-Checkpoint

### Phase 6: Settings & Polish
**Goal**: Admins can configure the app for their family's needs; child-safe UI modes work correctly; the app is ready for App Store submission
**App Store Submission ohne Mac**: Vollständig via GitHub Actions + fastlane möglich. Der macOS-Runner signiert die App und lädt sie zu App Store Connect hoch — kein lokaler Mac nötig. Setup: fastlane match (Zertifikate in Git-Repo) + fastlane deliver. Details in 06-04-PLAN.md ausgearbeitet.
**Depends on**: Phase 5
**Requirements**: SETTINGS-01, SETTINGS-02, KID-02, KID-03
**Success Criteria** (what must be TRUE):
  1. Admin can toggle any of the four activity categories on or off; disabled categories disappear from the logging UI, dashboard, and widgets for the entire family
  2. Admin can change the point multiplier for any active category; new multiplier applies to future entries only (historical entries unchanged)
  3. A member with the Child-simplified role sees a reduced UI: only their own score and tasks, large tap targets, no family comparison or settings access
  4. A member's UI mode (Adult / Child-simplified) can be changed by an Admin in Settings without requiring a device handoff
  5. App passes App Store technical checklist: no crashes on launch, privacy manifest present, no secrets in binary, correct entitlements on all targets
**Plans**: 4 plans
Plans:
- [ ] 06-01-PLAN.md — Wave 0: CategoryConfig-Model, CategoryServiceProtocol + MockCategoryService, CategoryServiceTests-Stubs, SQL-Migration (point_weight CHECK-Constraint), [BLOCKING] schema push
- [ ] 06-02-PLAN.md — Wave 1: CategoryService-Implementierung, SettingsView + CategorySettingsView + MemberSettingsView, MainTabView (Settings-Tab fuer Admin), FamilyScoreApp-Verdrahtung
- [ ] 06-03-PLAN.md — Wave 2: KindDashboardView (Kind-vereinfacht UI), RootView Kind-Routing (role == .child), Appetize-Checkpoint (SC-1 bis SC-4)
- [ ] 06-04-PLAN.md — Wave 3: PrivacyInfo.xcprivacy, fastlane-Konfiguration (Fastfile + Matchfile + Appfile), release.yml, Abschluss-Checkpoint

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 3/3 | Complete | 2026-05-15 |
| 2. Authentication | 2/3 + checkpoint | In Progress (checkpoint) | - |
| 3. Family Core | 3/4 + checkpoint | In Progress (checkpoint) | - |
| 4. Activity Logging & Dashboard | 2/4 | In Progress|  |
| 5. Real-time & Widgets | 0/4 | Ready to plan | - |
| 6. Settings & Polish | 0/4 | Planned | - |
