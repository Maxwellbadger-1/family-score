---
phase: 04-activity-logging-dashboard
plan: "01"
subsystem: activity-service
tags: [protocol, mock, tdd, sql, migration, wave-0]
dependency_graph:
  requires: [03-04]
  provides: [ActivityServiceProtocol, MockActivityService, ActivityServiceTests, RingProgressTests, phase4-rpcs-sql]
  affects: [04-02, 04-03, 04-04]
tech_stack:
  added: []
  patterns: [Protocol-First Wave 0, SECURITY DEFINER RPCs, XCTest Stubs, MainActor ObservableObject]
key_files:
  created:
    - FamilyScore/FamilyScore/Services/ActivityServiceProtocol.swift
    - FamilyScore/FamilyScoreTests/Mocks/MockActivityService.swift
    - FamilyScore/FamilyScoreTests/ActivityServiceTests.swift
    - FamilyScore/FamilyScoreTests/RingProgressTests.swift
    - FamilyScore/supabase/migrations/20260516_phase4_rpcs.sql
  modified:
    - FamilyScore/FamilyScore/Services/ActivityServiceProtocol.swift (RingType: Equatable hinzugefuegt)
decisions:
  - "ActivityServiceProtocol im App-Target definiert (analog AuthServiceProtocol in Phase 2) — MockActivityService importiert via @testable import"
  - "RingType: Equatable-Konformanz noetig fuer XCTAssertEqual in Tests (Rule 1 Fix)"
  - "AllTimeStats und fetchAllTimeStats() als DASH-04-Erweiterung zum Protocol hinzugefuegt"
  - "weeklyScores und familyDayScores als Protocol-Properties (Wave 1 braucht diese)"
metrics:
  duration_seconds: 198
  completed_date: "2026-05-22"
  tasks_completed: 4
  tasks_total: 4
  files_created: 5
  files_modified: 1
---

# Phase 4 Plan 01: Wave 0 Test-Infrastruktur + SQL-Migration Summary

**One-liner:** ActivityServiceProtocol mit 9 Model-Typen, MockActivityService (17 Tests) und 4 SECURITY DEFINER RPCs als Fundament fuer Phase-4-Implementation.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | ActivityServiceProtocol + alle Model-Typen | 475c676 | ActivityServiceProtocol.swift (neu) |
| 2 | MockActivityService + ActivityServiceTests + RingProgressTests | 9a7719f | 3 Test-Dateien + RingType:Equatable Fix |
| 3 | SQL-Migration 20260516_phase4_rpcs.sql | a120182 | 20260516_phase4_rpcs.sql (neu) |
| 4 | Supabase-Migration live eingespielt (4 RPCs) | — (MCP-Aktion) | Live-DB: get_today_score, get_family_today_scores, create_activity_for_child, insert_default_categories |

## What Was Built

### Task 1: ActivityServiceProtocol.swift
- **9 Model-Structs/Enums:** RingType, ActivityEntry, NewActivityEntry, CategoryConfig, DayScore, MemberDayScore, WeekMemberScore, WeeklySummary, CategoryBreakdown, AllTimeStats
- **ActivityServiceProtocol:** 11 State-Properties (read-only) + 1 Error-Property (read-write) + 8 Methoden
- **Target:** FamilyScore App ONLY, kein Supabase-Import
- **Swift 6:** Alle Typen Sendable, @MainActor Protocol

### Task 2: Test-Infrastruktur
- **MockActivityService:** Vollstaendige ActivityServiceProtocol-Implementierung, Verhaltens-Flags (shouldThrowOnLog, shouldThrowOnDelete), Zaehler fuer Call-Tracking
- **ActivityServiceTests:** 11 Test-Stubs (LOG-01 bis SCORE-03)
- **RingProgressTests:** 6 Unit-Tests fuer Ring-Progress-Logik (0%, 100%, Ueberlauf, Kategorie-Mapping)
- Alle Tests sind Stub-Tests (Wave 0) — laufen ohne Netzwerk

### Task 3: SQL-Migration
- **get_today_score:** Tagesscore mit Europe/Berlin-Timezone, CASE WHEN fuer duty/leisure Split
- **get_family_today_scores:** Alle Familienmitglieder via LEFT JOIN auf family_members
- **create_activity_for_child:** Eltern-Rolle-Pruefung (admin/adult), DoS-Cap 240 min (T-4-05)
- **insert_default_categories:** Idempotentes Seeding mit ON CONFLICT DO NOTHING
- Alle 4 RPCs: SECURITY DEFINER + SET search_path='' + COALESCE auf Aggregat-Spalten

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] RingType braucht Equatable fuer XCTAssertEqual**
- **Found during:** Task 2 (bei Erstellung der Test-Dateien)
- **Issue:** `XCTAssertEqual(haushalt.ringType, RingType.duty)` kompiliert nur wenn RingType Equatable conformt — war im Plan-Snippet nicht explizit
- **Fix:** `enum RingType: Equatable { case duty, leisure }` in ActivityServiceProtocol.swift
- **Files modified:** FamilyScore/FamilyScore/Services/ActivityServiceProtocol.swift
- **Commit:** 9a7719f

### Protocol-Erweiterung (Plan-Erweiterung, kein Bug)

Der Plan-Snapshot von ActivityServiceProtocol in PATTERNS.md hatte eine kleinere Methoden-Liste. Die vollstaendige Version aus dem PLAN.md-`<action>`-Block wurde implementiert:
- `fetchAllTimeStats()` fuer DASH-04 hinzugefuegt
- `weeklyScores: [WeeklySummary]` und `familyDayScores: [MemberDayScore]` als Properties
- `logActivityForChild(...)` als Methode
- `allTimeStats: AllTimeStats?` als Property

## Task 4: Supabase-Migration live eingespielt

**Status: ABGESCHLOSSEN**

`mcp__supabase__apply_migration` (migration_name: "phase4_rpcs") erfolgreich ausgefuehrt (success: true).

**Ergebnis in der Live-DB:**
- `get_today_score` — live
- `get_family_today_scores` — live
- `create_activity_for_child` — live
- `insert_default_categories` — live

**category_config:** Beide Testfamilien haben bereits 4 Kategorien (Haushalt, Hobby/Freizeit, Besorgungen, Arbeit/Schule) — kein Seeding per Hand noetig.

## Known Stubs

Die folgenden Test-Methoden sind intentionale Wave-0-Stubs (werden in Wave 1+ durch echte Assertions ersetzt):
- `ActivityServiceTests`: Alle 11 Methoden testen gegen MockActivityService, nicht gegen echte DB
- `RingProgressTests`: 6 Tests sind reine Berechnungs-Logik, kein Netzwerk

## Threat Flags

Keine neuen Threat-Flags — alle Threats aus dem Plan-Threat-Register wurden abgedeckt:
- T-4-01: `create_activity_for_child` prueft Eltern-Rolle (implementiert)
- T-4-05: DoS-Cap `LEAST(240, p_duration_min)` (implementiert)

## Self-Check: PASSED

Ergebnis der Datei-Pruefung:
- ActivityServiceProtocol.swift: GEFUNDEN
- MockActivityService.swift: GEFUNDEN
- ActivityServiceTests.swift: GEFUNDEN
- RingProgressTests.swift: GEFUNDEN
- 20260516_phase4_rpcs.sql: GEFUNDEN

Commit-Pruefung:
- 475c676 (Task 1): GEFUNDEN
- 9a7719f (Task 2): GEFUNDEN
- a120182 (Task 3): GEFUNDEN
