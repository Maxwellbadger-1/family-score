---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: in_progress
stopped_at: ~
last_updated: "2026-05-17T08:25:00.000Z"
last_activity: 2026-05-17 — Phase 3 Plan 02 (Wave 1) abgeschlossen — FamilyService + AuthService.refreshFamilyStatus() implementiert
progress:
  total_phases: 6
  completed_phases: 2
  total_plans: 11
  completed_plans: 8
  percent: 73
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-15)

**Core value:** Familienmitglieder sehen auf einen Blick, ob Pflichten und Freizeit fair aufgeteilt sind — Transparenz schafft Fairness ohne Diskussion
**Current focus:** Phase 3 — Family Core (executing)

## Current Position

Phase: 3 of 6 (Family Core)
Plan: 3 of 4 in current phase (Wave 2 — Views bereit)
Status: In Progress
Last activity: 2026-05-17 — Plan 03-02 (Wave 1) abgeschlossen; FamilyService (ObservableObject, alle 10 Protocol-Methoden, 4 RPCs) + AuthService.refreshFamilyStatus() implementiert

Progress: [██████░░░░] 64%

## Performance Metrics

**Velocity:**

- Total plans completed: 3
- Average duration: —
- Total execution time: —

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1. Foundation | 3 | — | — |
| 2. Authentication | 2 | ~22min | ~11min |

**Recent Trend:**

- Last 5 plans: 01-01, 01-02, 01-03, 02-01, 02-02, 03-01
- Trend: —

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Foundation: App Group entitlement must be verified on a real device before any widget UI work (Simulator silently succeeds, device silently fails)
- Foundation: Supabase SDK must NOT be linked to the Widget Extension target — widget reads only from App Group UserDefaults
- Foundation: Score is append-only — activity_entries summed server-side via DB trigger into weekly_summaries; no mutable total_score column ever
- Foundation: Realtime must be disconnected on background and reconnected (with a REST re-fetch first) on every scenePhase .active
- Auth Wave 0: AppState is final — Plan 02 does NOT modify it; AuthService reads/writes it via authStateChanges
- Auth Wave 0: AuthServiceProtocol defined in test target MockAuthService.swift; Plan 02 AuthService implicitly conforms
- Auth Wave 0: FamilyScoreTests Xcode target registration requires Mac (same pattern as Phase 1)
- Auth Wave 1: AuthService.startObserving() is NOT called in RootView — only FamilyScoreApp.swift (Plan 02-03) starts the loop to prevent two concurrent AsyncStream loops causing race conditions
- Auth Wave 1: ObservableObject + @Published used throughout Views and AuthService (NOT @Observable) — iOS 16.0 minimum enforced
- Auth Wave 1: KeychainLocalStorage(service: com.familyscore) added to Supabase.swift to prevent macOS/iOS Keychain prompt bug (Discussion #28132)
- Auth Wave 2: rawNonce an Supabase signInWithIdToken, sha256(rawNonce) an Apple request.nonce — NIEMALS vertauschen (Pitfall 3 mitigiert)
- Auth Wave 2: .task{} auf WindowGroup-Level in FamilyScoreApp.swift garantiert INITIAL_SESSION nie verpasst wird (Pitfall 2 mitigiert)
- Auth Wave 2: Sign in with Apple Capability muss manuell in Xcode aktiviert werden (Signing & Capabilities → + Capability → Sign in with Apple)
- Family Wave 0: FamilyServiceProtocol im Test-Target definiert (gleiche Entscheidung wie AuthServiceProtocol Phase 2)
- Family Wave 0: MemberRole als eigenstaendige Datei (nicht inline in FamilyService) — saubere Imports in Tests und Views
- Family Wave 0: SQL-Migration noch NICHT zur Datenbank gepusht — das ist Plan 02 Aufgabe (Supabase CLI push)
- Family Wave 1: FamilyService implementiert FamilyServiceProtocol strukturell (Duck-Typing) — Protocol im Test-Target, keine explizite Konformanz-Deklaration noetig
- Family Wave 1: updateProfile() verwendet direktes REST-UPDATE (nicht RPC) — RLS-Policy sichert display_name/avatar_color-Only ab; role/family_id unveraenderbar via diesem Pfad
- Family Wave 1: refreshFamilyStatus() in AuthService (nicht FamilyService) — Dependency-Richtung Views -> Services eingehalten

### Pending Todos

None yet.

### Blockers/Concerns

- Phase 4: Three open design decisions must be resolved before ring UI is locked — (1) three rings vs. one aggregate ring per person, (2) rolling 7-day vs. calendar week for score windows, (3) point scale (target 100–500 pts/productive week)
- Phase 5: WidgetKit APNs push for widget updates when main app is backgrounded needs a spike before full implementation

## Deferred Items

Items acknowledged and carried forward:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| v2 | Time equity fairness dashboard (Duty vs. Free ratio for adult couples) | Deferred | Roadmap |
| v2 | Rolling streak system with grace periods | Deferred | Roadmap |
| v2 | Recurring activities + rotation assignment | Deferred | Roadmap |
| v2 | SwiftData offline-first persistence | Deferred | Roadmap |
| v2 | Child-assisted UI progression (teen → adult) | Deferred | Roadmap |

## Session Continuity

Last session: 2026-05-17T08:25:00.000Z
Stopped at: Completed 03-02-PLAN.md (Wave 1 abgeschlossen)
Resume file: None
