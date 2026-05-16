# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-15)

**Core value:** Familienmitglieder sehen auf einen Blick, ob Pflichten und Freizeit fair aufgeteilt sind — Transparenz schafft Fairness ohne Diskussion
**Current focus:** Phase 2 — Authentication (executing)

## Current Position

Phase: 2 of 6 (Authentication)
Plan: 1 of 3 in current phase
Status: In Progress (executing)
Last activity: 2026-05-16 — 02-01 complete (Wave 0: XCTest infrastructure — AppState, MockAuthService, AuthServiceTests)

Progress: [██░░░░░░░░] 22%

## Performance Metrics

**Velocity:**
- Total plans completed: 3
- Average duration: —
- Total execution time: —

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1. Foundation | 3 | — | — |
| 2. Authentication | 1 | ~2min | ~2min |

**Recent Trend:**
- Last 5 plans: 01-01, 01-02, 01-03, 02-01
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

Last session: 2026-05-16
Stopped at: Phase 2 Plan 01 complete — XCTest Wave 0 infrastructure: AppState.swift, MockAuthService.swift, AuthServiceTests.swift (8 stubs). FamilyScoreTests Xcode target registration requires Mac.
Resume file: None
