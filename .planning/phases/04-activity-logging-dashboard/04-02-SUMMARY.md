---
phase: 04-activity-logging-dashboard
plan: "02"
subsystem: activity-service
tags: [service, crud, optimistic-ui, timer, rpc, tdd, wave-1]
dependency_graph:
  requires: [04-01]
  provides: [ActivityService, ActivityEntry-stub]
  affects: [04-03, 04-04]
tech_stack:
  added: []
  patterns:
    - "@MainActor ObservableObject mit ActivityServiceProtocol-Konformanz"
    - "Optimistic UI (Insert + Delete) mit Rollback"
    - "Timer-Persistenz via @AppStorage (Double/String — Pitfall 2 mitigiert)"
    - "SECURITY DEFINER RPC fuer Kind-Eintraege (T-4-01)"
    - "Family-weiter Familien-Feed ohne user_id-Filter (DASH-05)"
key_files:
  created:
    - FamilyScore/FamilyScore/Services/ActivityService.swift
    - FamilyScore/FamilyScore/Models/ActivityEntry.swift
  modified:
    - FamilyScore/FamilyScoreTests/ActivityServiceTests.swift
decisions:
  - "currentFamilyId als settable Property (nicht aus AuthService abgeleitet) — FamilyScoreApp.swift setzt sie nach Family-Load; Dependency-Richtung Views->Services bleibt eingehalten"
  - "fetchAllTimeStats() laedt alle Eintraege und summiert Swift-seitig — kein PostgREST-Aggregat (Phase 4 Vereinfachung; Phase 6 Trigger-Refactoring geplant)"
  - "fetchTodayData() nutzt gte/lt auf logged_at statt PostgreSQL date()-Cast — kompatibel mit supabase-swift v2.46.0 ohne RPC-Dependency"
  - "duration_minutes auf max(1, min(240, ...)) gecappt Swift-seitig in logActivity(), logActivityForChild() UND stopTimer() — alle drei Einstiegspunkte abgesichert"
metrics:
  duration_seconds: 480
  completed_date: "2026-05-22"
  tasks_completed: 2
  tasks_total: 2
  files_created: 2
  files_modified: 1
---

# Phase 4 Plan 02: ActivityService Wave 1 Summary

**One-liner:** ActivityService.swift als @MainActor ObservableObject mit CRUD, Optimistic UI, Timer-Persistenz via @AppStorage und SECURITY DEFINER RPC fuer Kind-Eintraege.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | ActivityService.swift implementieren | f1621d5 | ActivityService.swift (351 Zeilen, neu) |
| 2 | ActivityEntry.swift Stub + ActivityServiceTests Wave-1-Assertions | 2a3e8bb | ActivityEntry.swift (neu), ActivityServiceTests.swift (16 Tests) |

## What Was Built

### Task 1: ActivityService.swift

**Vollstaendige ActivityServiceProtocol-Konformanz:**
- `@MainActor final class ActivityService: ObservableObject, ActivityServiceProtocol`
- 11 `@Published private(set)` State-Properties + `activityError` ohne `private(set)`
- `allTimeStats: AllTimeStats?` fuer DASH-04

**Datenzugriff:**
- `fetchTodayData()`: Kategorien (category_config) → Eintraege (activity_entries, family-weiter Query ohne user_id-Filter — DASH-05) → Tagesscore (`get_today_score` RPC) → `refreshLocalRingProgress()`
- `fetchFamilyData()`: `get_family_today_scores` RPC fuer Familien-Vergleich (DASH-02)
- `fetchWeeklyData()`: weekly_summaries ORDER BY week_start DESC (DASH-03)
- `fetchAllTimeStats()`: Alle Eintraege per family_id/user_id, summiert Swift-seitig (DASH-04)

**CRUD mit Optimistic UI:**
- `logActivity()`: Temp-UUID-Eintrag sofort einsetzen → INSERT → echten Eintrag einsetzen → `get_today_score` RPC neu laden (Pitfall 6) → Rollback bei Fehler
- `logActivityForChild()`: Ausschliesslich via `create_activity_for_child` SECURITY DEFINER RPC — kein direktes INSERT mit fremder user_id (T-4-01 mitigiert)
- `deleteActivity()`: Optimistic Remove → DELETE → Rollback bei Fehler (RLS entscheidet, T-4-02 accepted)

**Timer:**
- `@AppStorage("timerStartedAt")` als Double (Pitfall 2: UUID nicht direkt in @AppStorage)
- `@AppStorage("timerCategoryId")` als String
- `stopTimer()`: Dauer aus Start-Timestamp berechnen, logActivity() aufrufen
- Timer-Dauer ebenfalls auf max(1, min(240, ...)) gecappt (T-4-05)

**Sicherheit:**
- `duration_minutes` auf `max(1, min(240, ...))` in allen 3 Einstiegspunkten (T-4-05 DoS-Schutz)
- `currentFamilyId` aus der Session (nicht client-manipulierbar via RLS als zweite Linie, T-4-04)

**Ring-Progress:**
- `refreshLocalRingProgress()` berechnet dutyProgress/leisureProgress/scoreProgress aus lokalen todayEntries
- 60 pts = Ring full (UI-SPEC Score Contract)
- Niemals akkumuliert gespeichert (CLAUDE.md Architektur-Regel)

**351 Zeilen** — erfuellt Mindestanforderung von 200 Zeilen.

### Task 2: Stub + Tests

**ActivityEntry.swift**: Hinweis-Datei — alle Modelle liegen in ActivityServiceProtocol.swift, keine Code-Duplikation.

**ActivityServiceTests.swift**: 16 Tests (11 Wave-0-Stubs + 5 neue Wave-1-Assertions):
- `testLogActivityPassesDurationCorrectly` (LOG-02)
- `testLogActivityThrowsWhenFlagSet` (LOG-05)
- `testLeisureProgressReadable` (DASH-01)
- `testLogForChildIncreasesCountCorrectly` (LOG-04)
- `testStopTimerCallsLogAndStopsTimer` (LOG-01)

**xcodebuild-Verifikation:** Kein lokales Xcode (Windows-CI-First Workflow per CLAUDE.md). Verifizierung erfolgt via CI auf dem macOS-Runner nach Push (GitHub Actions).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] fetchTodayData() via gte/lt statt PostgreSQL date()-Cast**
- **Found during:** Task 1 (bei Implementierung von fetchTodayData())
- **Issue:** Der Plan nennt `WHERE date(logged_at) = today` — PostgREST unterstuetzt keinen direkten date()-Cast-Filter ohne RPC in supabase-swift v2.46.0. Alternativ: activity_entries-Query via gte/lt auf logged_at.
- **Fix:** `gte("logged_at", value: todayISO).lt("logged_at", value: tomorrowISO)` — semantisch identisch, ohne zusaetzliche RPC-Dependency.
- **Files modified:** FamilyScore/FamilyScore/Services/ActivityService.swift

**2. [Rule 2 - Missing Critical] Timer-Dauer-Cap auch in stopTimer() eingefuegt**
- **Found during:** Task 1 (Review der Sicherheits-Anforderungen)
- **Issue:** Plan zeigt DoS-Cap nur in logActivity() und logActivityForChild(). stopTimer() ruft zwar logActivity() auf, aber der Plan macht es nicht explizit fuer stopTimer() klar.
- **Fix:** `max(1, min(240, Int(...)))` auch explizit in stopTimer() vor dem logActivity()-Aufruf berechnet (extra Sicherheitsebene, da stopTimer() die Minuten berechnet bevor logActivity() sie kappend).
- **Files modified:** FamilyScore/FamilyScore/Services/ActivityService.swift

**3. [Rule 1 - Vereinfachung] fetchAllTimeStats() Swift-seitig summiert**
- **Found during:** Task 1 (bei Implementierung von DASH-04)
- **Issue:** Der Plan beschreibt `SELECT SUM()` — PostgREST kann keine echte SQL-Aggregation ohne RPC in supabase-swift (`.rpc()` waere eine neue Migration noetig). Phase 4 hat bereits 4 RPCs; eine weitere fuer DASH-04 wuerde den Scope ueberziehen.
- **Fix:** Alle Eintraege per user_id/family_id laden und Swift-seitig mit `.reduce()` summieren. Korrekt, da DASH-04 nur Gesamt-Statistiken sind, nicht realtime-kritisch.
- **Commit:** f1621d5

## Known Stubs

- `fetchAllTimeStats()` laedt alle Eintraege Swift-seitig — bei grossen Datenmengen (> 1000 Eintraege) ineffizient. Phase 6 soll einen DB-Trigger uebernehmen (SCORE-02 Tracking). Fuer Phase 4 (Testphase, wenige Eintraege) akzeptabel.

## Threat Flags

Keine neuen Threats. Alle Threats aus dem Plan-Threat-Register implementiert:
- T-4-01: `create_activity_for_child` ausschliesslich via SECURITY DEFINER RPC (implementiert)
- T-4-02: deleteActivity() hat keinen Swift-seitigen Role-Check — RLS entscheidet (akzeptiert per Plan)
- T-4-03: Client berechnet points (Phase 4 akzeptiert; Phase 6 DB-Trigger)
- T-4-04: currentFamilyId aus authentifizierter Session (implementiert)
- T-4-05: duration_minutes gecappt max(1, min(240,...)) in allen 3 Einstiegspunkten (implementiert)

## Self-Check: PASSED

Datei-Pruefung:
- ActivityService.swift: GEFUNDEN (351 Zeilen)
- ActivityEntry.swift: GEFUNDEN (Stub)
- ActivityServiceTests.swift: GEFUNDEN (16 Tests)

Commit-Pruefung:
- f1621d5 (Task 1 ActivityService): GEFUNDEN
- 2a3e8bb (Task 2 Stub + Tests): GEFUNDEN

Akzeptanzkriterien:
- class ActivityService: ObservableObject, ActivityServiceProtocol: GEFUNDEN
- @MainActor: GEFUNDEN
- @preconcurrency import Supabase: GEFUNDEN
- rpc("get_today_score"): GEFUNDEN (2x — in fetchTodayData und logActivity)
- rpc("create_activity_for_child"): GEFUNDEN
- from("activity_entries").insert: GEFUNDEN
- from("activity_entries").delete: GEFUNDEN
- timerStartedAtInterval, timerCategoryIdString (@AppStorage): GEFUNDEN
- min(240) DoS-Cap: GEFUNDEN (3x)
- / 60.0 Ring-Progress: GEFUNDEN (3x)
- allTimeStats: GEFUNDEN
- fetchAllTimeStats(): GEFUNDEN
- Kein user_id-Filter in fetchTodayData() activity_entries-Query: BESTAETIGT
