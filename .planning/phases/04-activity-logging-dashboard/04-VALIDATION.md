---
phase: 4
slug: activity-logging-dashboard
status: draft
nyquist_compliant: true
nyquist_note: "Wave-0 RingProgressTests.swift deckt Ring-Progress-Berechnung (duty/leisure/score, 0%, 100%, Ueberlauf) ab. Cmd+U wird nach jedem Task-Commit ausgefuehrt. Wave-2-Tasks (04-03 Task 1) referenzieren RingProgressTests explizit als verify-Schritt — damit ist die Kette lueckenlos: Wave0→Wave1→Wave2→Wave3 haben alle Unit-Test-Abdeckung."
wave_0_complete: false
created: 2026-05-16
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (FamilyScoreTests Target — konfiguriert in Phase 2) |
| **Config file** | Xcode-Projekt (kein separates File) |
| **Quick run command** | `Cmd+U` in Xcode |
| **Full suite command** | `xcodebuild test -scheme FamilyScore -destination 'platform=iOS Simulator,name=iPhone 16'` |
| **Estimated runtime** | ~15 Sekunden |

---

## Sampling Rate

- **After every task commit:** Run `Cmd+U` (Unit-Tests: ActivityServiceTests + RingProgressTests)
- **After every plan wave:** Run full suite (`xcodebuild test ...`)
- **Before `/gsd-verify-work`:** Full suite grün + Gerät-Checkpoint (echtes Gerät, echter JWT)
- **Max feedback latency:** ~15 Sekunden (Unit-Tests), manuell für Gerät-Checkpoint

---

## Nyquist Compliance Note

Wave 2 (04-03) hat keine eigenen Unit-Tests für RingClusterView oder WeekSummaryView direkt, aber:

- **Wave 0** erstellt `RingProgressTests.swift` mit 6 Unit-Tests die Ring-Progress-Berechnung (0%, 100%, Überlauf, duty/leisure-Mapping) vollständig abdecken.
- **04-03 Task 1** (SingleRingView + RingClusterView) hat `xcodebuild test -only-testing:FamilyScoreTests/RingProgressTests` als `<automated>` verify-Schritt — damit läuft nach Wave-2-Task-1 ein Unit-Test.
- **04-03 Task 2** (DashboardView + WeekSummaryView) hat `xcodebuild build` als verify — kein Gap da Wave-0-Tests die Logik abdecken und der Build-Check Kompilierung sichert.
- **04-03 Task 3** (ActivityLogSheet) hat `xcodebuild build` — reine UI-Glue, keine testbare Logik.
- **04-04 Task 2** (App-Verdrahtung) hat `xcodebuild test` (volle Suite) als verify.

Sampling-Kette: Wave0(Cmd+U) → Wave1(Cmd+U) → Wave2-T1(RingProgressTests) → Wave2-T2(build) → Wave2-T3(build) → Wave3-T1(build) → Wave3-T2(volle Suite). Keine 3 aufeinanderfolgenden Tasks ohne automatisierten Check.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 4-01-01 | 01 | 0 | LOG-01, LOG-02 | T-4-01 | ActivityServiceProtocol + MockActivityService | unit | `Cmd+U` | ❌ W0 | ⬜ pending |
| 4-01-02 | 01 | 0 | LOG-01 | — | Timer-Start/-Stop-Logik, AppStorage-Persistenz | unit | `Cmd+U` | ❌ W0 | ⬜ pending |
| 4-01-03 | 01 | 0 | DASH-01, SCORE-02 | — | Ring-Progress-Berechnung (duty/leisure/score), Kein Akkumulieren | unit | `Cmd+U` | ❌ W0 | ⬜ pending |
| 4-02-01 | 02 | 1 | LOG-06 | T-4-03 | category_config Seed + Mapping Pflicht/Freizeit korrekt | integration | Gerät-Checkpoint | — | ⬜ pending |
| 4-02-02 | 02 | 1 | LOG-01, LOG-02 | — | ActivityService logActivity() + optimistic UI | unit | `Cmd+U` | ❌ W0 | ⬜ pending |
| 4-02-03 | 02 | 1 | LOG-04 | T-4-01 | create_activity_for_child RPC — Eltern-Kind-Beziehung | unit (Mock) | `Cmd+U` | ❌ W0 | ⬜ pending |
| 4-02-04 | 02 | 1 | LOG-05 | T-4-02 | deleteActivity() — RLS prüft owner/admin | integration | Gerät-Checkpoint | — | ⬜ pending |
| 4-03-01 | 03 | 2 | DASH-01 | — | RingClusterView rendert korrekte Farben + Positionen; RingProgressTests gruen | unit | `xcodebuild test -only-testing:FamilyScoreTests/RingProgressTests` | ✅ W0 | ⬜ pending |
| 4-03-02 | 03 | 2 | DASH-02, DASH-03 | — | DashboardView + WeekSummaryView mit Wochensieger + Pflicht/Freizeit-Labels | build | `xcodebuild build` | ❌ W2 | ⬜ pending |
| 4-03-03 | 03 | 2 | LOG-02, LOG-03 | — | ActivityLogSheet: Kategorie, Picker, Punkte-Vorschau, async Save | build | `xcodebuild build` | ❌ W2 | ⬜ pending |
| 4-04-01 | 04 | 3 | DASH-04, DASH-05 | — | ActivityListView: family-weiter Feed + 'Alle Zeit'-Section | build | `xcodebuild build` | ❌ W3 | ⬜ pending |
| 4-04-02 | 04 | 3 | SCORE-01, SCORE-02, SCORE-03 | — | App-Verdrahtung + currentFamilyId-Injection + volle Test-Suite gruen | unit+integration | `xcodebuild test` | ❌ W3 | ⬜ pending |
| 4-04-03 | 04 | 3 | DASH-04 | — | Gesamt-Statistiken: SUM über alle activity_entries ohne Datumsfilter | integration | Gerät-Checkpoint | — | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `FamilyScoreTests/ActivityServiceTests.swift` — 10+ Stubs (LOG-01 bis SCORE-03)
- [ ] `FamilyScoreTests/Mocks/MockActivityService.swift` — ActivityServiceProtocol + Mock-Implementierung (inkl. fetchAllTimeStats())
- [ ] `FamilyScoreTests/RingProgressTests.swift` — Unit-Tests für Ring-Progress-Berechnung + Überlauf > 100%
- [ ] `FamilyScore/Services/ActivityServiceProtocol.swift` — Protocol-Definition inkl. AllTimeStats-Model + fetchAllTimeStats()

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| RLS: Eintrag löschen (eigener vs. Admin) | LOG-05 | RLS nur mit echtem JWT testbar (Dashboard bypassed RLS) | Echtes Gerät: (1) als normaler User Eintrag löschen → OK; (2) fremden Eintrag löschen → muss fehlschlagen; (3) als Admin fremden Eintrag löschen → OK |
| Score-Aggregation end-to-end | SCORE-01, SCORE-02, SCORE-03 | Supabase RPC + Trigger + iOS-Client zusammen | Echtes Gerät: Aktivität loggen → Ring-Update sichtbar → `weekly_summaries` in Supabase prüfen |
| category_config Seeding | LOG-06 | Requires Supabase project + Migration | Supabase SQL-Editor: `SELECT * FROM category_config` — 4 Standardkategorien vorhanden |
| Timer-Persistenz durch App-Kill | LOG-01 | Background-Verhalten nur auf echtem Gerät | Echtes Gerät: Timer starten → App beenden → App neu starten → Timer läuft weiter mit korrekter Zeit |
| Timezone-Korrektheit (Wochenbeginn) | SCORE-03 | UTC vs. Europe/Berlin nur live testbar | Supabase: Projekt-Timezone prüfen; Testfall: Aktivität Sonntag 23:30 Lokal einloggen → erscheint in richtiger Woche |
| Gesamt-Statistiken korrekt (DASH-04) | DASH-04 | Supabase-Aggregation nur mit echten Daten prüfbar | Echtes Gerät: Nach mehreren Aktivitäten → Verlauf-Tab → 'Alle Zeit'-Section zeigt korrekte Summen; mit `SELECT SUM(duration_minutes), SUM(points) FROM activity_entries WHERE family_id = '<id>'` verifizieren |
| Family-Feed vollständig (DASH-05) | DASH-05 | RLS + multi-user nur auf Gerät testbar | Echtes Gerät: Zwei Familienmitglieder loggen Aktivitäten → Verlauf-Tab beider zeigt alle Einträge der Familie |

---

## Resolved Open Questions (aus RESEARCH.md)

| Frage | Resolution |
|-------|-----------|
| Frage 1: Timezone-Handling | (RESOLVED) SQL-Migration 20260516_phase4_rpcs.sql verwendet `AT TIME ZONE 'Europe/Berlin'` in allen Datums-Berechnungen |
| Frage 2: Kind-Profile: auth.users oder nur family_members? | (OPEN) Phase 4 implementiert create_activity_for_child RPC mit `user_id = fm.id` aus family_members. Kinder brauchen keinen auth.users-Account für Aktivitäts-Einträge — Eltern erstellen diese via RPC. Vollständige Kind-UI deferred auf Phase 6. |
| Frage 3: category_config Seeding | (RESOLVED) insert_default_categories() RPC in 20260516_phase4_rpcs.sql; wird von FamilyService (Phase 3) bei create_family() aufgerufen |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [x] Feedback latency < 15s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
