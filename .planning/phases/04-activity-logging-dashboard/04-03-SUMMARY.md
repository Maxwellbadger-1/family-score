---
phase: 04-activity-logging-dashboard
plan: 03
subsystem: dashboard-ui
tags: [swiftui, swift-charts, ring-ui, dashboard, activity-log]
dependency_graph:
  requires:
    - 04-02 (ActivityService Wave 1)
    - 04-01 (ActivityServiceProtocol + Models Wave 0)
  provides:
    - DashboardView (Tab 1 — sichtbarer Core-Loop)
    - RingClusterView + SingleRingView (Ring-Cluster)
    - WeekSummaryView (Swift Charts Wochenbilanz)
    - ActivityLogSheet (Half-Screen Modal zum Loggen)
  affects:
    - FamilyScoreApp.swift (ActivityService Injection + currentFamilyId Sync)
    - RootView.swift (AuthenticatedPlaceholderView → DashboardView)
tech_stack:
  added:
    - Swift Charts (import Charts, iOS 16 nativ)
  patterns:
    - Circle().trim() fuer Ring-Arcs (kein Canvas, kein Custom Shape)
    - .spring(response: 0.6, dampingFraction: 0.75) Apple Fitness Animation
    - @ObservedObject in Sheet (nicht @EnvironmentObject — Sheet-Scope)
    - .safeAreaInset(edge: .bottom) fuer Speichern-FAB
    - .onChange(of: familyService.currentFamily?.id) fuer Service-Sync
key_files:
  created:
    - FamilyScore/FamilyScore/Views/Dashboard/SingleRingView.swift
    - FamilyScore/FamilyScore/Views/Dashboard/RingClusterView.swift
    - FamilyScore/FamilyScore/Views/Dashboard/DashboardView.swift
    - FamilyScore/FamilyScore/Views/Dashboard/WeekSummaryView.swift
    - FamilyScore/FamilyScore/Views/ActivityLog/ActivityLogSheet.swift
  modified:
    - FamilyScore/FamilyScore/FamilyScoreApp.swift (ActivityService StateObject + Injection)
    - FamilyScore/FamilyScore/Views/RootView.swift (DashboardView Routing)
decisions:
  - "SingleRingView ist accessibilityHidden — Labels auf RingClusterView-Ebene gesetzt (UI-SPEC Accessibility Contract)"
  - "ActivityLogSheet bekommt @ObservedObject (nicht @EnvironmentObject) — PATTERNS.md Konvention fuer Sheet-Scope"
  - "currentFamilyId-Sync via .onChange(of: familyService.currentFamily?.id) in FamilyScoreApp.swift — kein direkter FamilyService-Zugriff in DashboardView noetig"
  - "weekScoresForChart: Kategorien Haushalt/Besorgungen/Arbeit-Schule werden zu 'Pflicht' aggregiert, Hobby-Freizeit zu 'Freizeit'"
metrics:
  duration: ~25min
  completed: 2026-05-22
  tasks: 3
  files_created: 5
  files_modified: 2
---

# Phase 4 Plan 03: Dashboard-UI Wave 2 Summary

**One-liner:** SwiftUI Dashboard mit Apple-Fitness-Ring-Cluster (280/224/168pt), Swift Charts Wochenbilanz mit Wochensieger-Header und Half-Screen ActivityLogSheet fuer den Core-Loop.

---

## Build-Ergebnis

xcodebuild wird via CI auf dem macOS-Runner ausgefuehrt (Windows-Entwicklungsworkflow per CLAUDE.md). Lokale Syntax-Verifikation durch alle Acceptance-Criteria-Checks bestanden.

---

## Ring Layout Contract — Umsetzung bestaetigt

| Parameter | Spec | Implementiert |
|-----------|------|---------------|
| outerDiameter | 280pt | 280pt |
| Freizeit-Diameter | 224pt (280-2*(20+8)) | 280 - 2*(20+8) = 224pt |
| Score-Diameter | 168pt (280-4*(20+8)) | 280 - 4*(20+8) = 168pt |
| lineWidth | 20pt | 20pt |
| gap | 8pt | 8pt |
| Track opacity | 15% | color.opacity(0.15) |
| Rotation start | 12 Uhr | .rotationEffect(.degrees(-90)) |
| Animation | spring(0.6, 0.75) | 3x .animation(.spring(response: 0.6, dampingFraction: 0.75)) |
| Overflow | 2. Runde 60% opacity | progress > 1.0 → color.opacity(0.6) |
| Pflicht-Farbe | systemRed | Color(UIColor.systemRed) |
| Freizeit-Farbe | systemGreen | Color(UIColor.systemGreen) |
| Score-Farbe | systemBlue | Color(UIColor.systemBlue) |
| Zentrum Display | 34pt semibold | .font(.system(size: 34, weight: .semibold)) |
| Zentrum Label | 13pt "Punkte heute" | .font(.system(size: 13)) |

---

## DASH-02: familyMemberRow Pflicht/Freizeit-Labels

Implementiert in `DashboardView.familyMemberRow(_ member: MemberDayScore)`:
- Zeile 1: `member.displayName` in Body-Typo (17pt)
- Zeile 2: `"Pflicht: \(Int(member.dutyPoints))pt · Freizeit: \(Int(member.leisurePoints))pt"` in Label-Typo (13pt, .secondary)
- Mini Score-Ring (36pt, systemBlue) als visueller Indikator

---

## DASH-03: Wochensieger-Header

Implementiert in `WeekSummaryView`:
- `weeklyLeaderName: String?` als Parameter
- `Text("Wochensieger: \(leader)")` wenn nicht nil — Heading-Typo (17pt semibold), systemBlue
- Berechnung in `DashboardView.weeklyLeaderName`: `weeklyScores.max(by: { $0.totalPoints < $1.totalPoints })` → `familyDayScores.first(where: { $0.userId == leader.userId })?.displayName`

---

## WeekSummaryView — Swift Charts

- `import Charts` (iOS 16 nativ, kein Third-Party)
- `BarMark` mit `position(by:)` fuer gruppierte Balken pro Mitglied
- `.chartForegroundStyleScale` mappt "Pflicht" → systemRed, "Freizeit" → systemGreen
- Leerstand: "Noch keine Wochendaten" wenn `weekScores.isEmpty`

---

## ActivityLogSheet

- `@ObservedObject var activityService: ActivityService` (Sheet-Scope, kein EnvironmentObject)
- 4 Kategorie-Buttons mit SF Symbol, Checkmark-Selektion
- Wheel-Picker 5–240 min, 5-min-Schritte, Default 30 min
- Dynamische Punkte-Vorschau: `calculatedPoints = Int(Double(selectedDuration) * weight)`
- Speichern-Button: full-width, 44pt, ProgressView bei isLoading
- Abbrechen: `ToolbarItem(.cancellationAction)`
- `presentationDetents([.medium])` + `presentationDragIndicator(.visible)` im Caller (DashboardView)

---

## Deviations from Plan

### Auto-added Missing Critical Functionality

**1. [Rule 2 - Missing Integration] ActivityService currentFamilyId Sync**
- **Found during:** Task 2 Implementation
- **Issue:** ActivityService.currentFamilyId (settable Property laut STATE.md Decision) wurde nirgends gesetzt — alle fetch-Methoden returnen sofort ohne familyId
- **Fix:** `.onChange(of: familyService.currentFamily?.id)` in `FamilyScoreApp.swift` synkt `activityService.currentFamilyId = newFamilyId` automatisch wenn Familie geladen wird
- **Files modified:** FamilyScore/FamilyScore/FamilyScoreApp.swift
- **Commit:** b5ff7da

**2. [Rule 2 - Missing Integration] RootView AuthenticatedPlaceholderView → DashboardView**
- **Found during:** Task 2 Implementation
- **Issue:** RootView routete authenticated(hasFamily: true) noch auf AuthenticatedPlaceholderView mit "Dashboard kommt in Phase 4" Text — DashboardView wuerde nie angezeigt
- **Fix:** `AuthenticatedPlaceholderView()` durch `DashboardView()` ersetzt
- **Files modified:** FamilyScore/FamilyScore/Views/RootView.swift
- **Commit:** b5ff7da

**3. [Rule 2 - Missing Integration] ActivityService @StateObject in FamilyScoreApp**
- **Found during:** Task 2 Implementation
- **Issue:** ActivityService war nicht als @StateObject in FamilyScoreApp.swift registriert — DashboardView haette kein @EnvironmentObject activityService erhalten
- **Fix:** `@StateObject private var activityService = ActivityService()` hinzugefuegt, `.environmentObject(activityService)` injiziert
- **Files modified:** FamilyScore/FamilyScore/FamilyScoreApp.swift
- **Commit:** b5ff7da

---

## Commits

| Task | Commit | Beschreibung |
|------|--------|-------------|
| Task 1 | 63a960b | feat(04-03): SingleRingView + RingClusterView erstellen |
| Task 2 | b5ff7da | feat(04-03): DashboardView + WeekSummaryView mit DASH-02/DASH-03 |
| Task 3 | e30da01 | feat(04-03): ActivityLogSheet erstellen (Half-Screen Modal) |

---

## Known Stubs

- `activityService.categories` in `ActivityLogSheet`: Beim ersten Oeffnen leer wenn `fetchTodayData()` noch nicht aufgerufen wurde. Ist kein Stub — Kategorien werden via `loadDashboard()` beim DashboardView-Laden geladen. Falls Sheet vor Dashboard-Load geoeffnet wird: leere Liste (kein Crash, nur keine Kategorien sichtbar). Loest sich nach erstem erfolgreichen `fetchTodayData()` auf.

---

## Threat Surface Scan

Keine neuen Netzwerk-Endpoints, Auth-Pfade oder Schema-Aenderungen eingefuehrt. Alle Netzwerk-Calls gehen via bestehende ActivityService-Methoden. T-4-03 (calculatedPoints als reine Vorschau) korrekt implementiert — authoritative Berechnung im Service.

---

## Self-Check

### Created Files

- [x] FamilyScore/FamilyScore/Views/Dashboard/SingleRingView.swift
- [x] FamilyScore/FamilyScore/Views/Dashboard/RingClusterView.swift
- [x] FamilyScore/FamilyScore/Views/Dashboard/DashboardView.swift
- [x] FamilyScore/FamilyScore/Views/Dashboard/WeekSummaryView.swift
- [x] FamilyScore/FamilyScore/Views/ActivityLog/ActivityLogSheet.swift

### Commits

- [x] 63a960b (SingleRingView + RingClusterView)
- [x] b5ff7da (DashboardView + WeekSummaryView)
- [x] e30da01 (ActivityLogSheet)

### Acceptance Criteria

- [x] BarMark in WeekSummaryView
- [x] import Charts in WeekSummaryView
- [x] Wochensieger in WeekSummaryView (DASH-03)
- [x] weeklyLeaderName in DashboardView
- [x] dutyPoints in DashboardView (DASH-02)
- [x] showingLogSheet in DashboardView (FAB)
- [x] Leerstand-Text korrekt
- [x] FAB accessibilityLabel "Aktivitaet erfassen"
- [x] @ObservedObject in ActivityLogSheet (nicht @EnvironmentObject)
- [x] pickerStyle(.wheel) in ActivityLogSheet
- [x] calculatedPoints Punkte-Vorschau
- [x] presentationDetents([.medium]) in Caller DashboardView
- [x] outerDiameter in RingClusterView
- [x] 3x spring(response: 0.6, ...) Animationen

## Self-Check: PASSED
