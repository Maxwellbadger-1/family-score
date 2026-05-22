---
phase: 04-activity-logging-dashboard
plan: "04"
subsystem: activity-list-app-wiring
tags: [swiftui, activity-list, tab-view, swipe-delete, family-feed, all-time-stats]
dependency_graph:
  requires:
    - 04-03 (Dashboard-UI Wave 2)
    - 04-02 (ActivityService Wave 1)
    - 04-01 (ActivityServiceProtocol + Models Wave 0)
  provides:
    - ActivityListView (Tab 2: family-weiter Feed + Alle-Zeit-Section + Swipe-Delete)
    - ActivityRowView (wiederverwendbare List-Zeile mit SF Symbol + ringColor)
    - RootView TabView (DashboardView + ActivityListView Tabs)
  affects:
    - FamilyScore/FamilyScore/Views/RootView.swift (authenticated-Zweig jetzt TabView)
tech_stack:
  added: []
  patterns:
    - ".swipeActions(edge: .trailing, allowsFullSwipe: false) statt .onDelete (Pitfall 5)"
    - ".confirmationDialog + titleVisibility: .visible fuer Loeschen-Bestaetigung"
    - "Section-Gruppierung via Dictionary(grouping:) nach startOfDay"
    - "@EnvironmentObject activityService in ActivityListView (kein @ObservedObject)"
    - "TabView mit zwei Tabs in RootView authenticated(hasFamily: true)"
key_files:
  created:
    - FamilyScore/FamilyScore/Views/ActivityLog/ActivityListView.swift
    - FamilyScore/FamilyScore/Views/ActivityLog/ActivityRowView.swift
  modified:
    - FamilyScore/FamilyScore/Views/RootView.swift (TabView statt einzelne DashboardView)
decisions:
  - "ActivityListView erhaelt @EnvironmentObject activityService — kein extra @StateObject noetig (bereits in FamilyScoreApp.swift)"
  - "currentFamilyId-Injection bleibt in FamilyScoreApp.swift via .onChange(of: familyService.currentFamily?.id) — kein zweites .onChange in RootView (Pitfall: Race Condition)"
  - "FamilyScoreApp.swift war bereits vollstaendig aus Wave 2 (Plan 04-03) — keine Aenderungen notwendig"
  - "xcodebuild-Test via CI (GitHub Actions) nicht verifizierbar wegen Billing-Blocker — Code-Review und statische Analyse durchgefuehrt"
  - "groupedByDay nutzt activityService.todayEntries (keine Datumsfilterung in View — ActivityService liefert family-weiten Feed ohne user_id-Filter)"
metrics:
  duration_seconds: 242
  completed_date: "2026-05-22"
  tasks_completed: 2
  tasks_total: 3
  files_created: 2
  files_modified: 1
---

# Phase 4 Plan 04: Aktivitaets-Verlauf + App-Verdrahtung Summary

**One-liner:** ActivityListView mit family-weitem Feed (DASH-05), Alle-Zeit-Section (DASH-04), swipeActions-Delete-Flow und TabView-Integration in RootView.

---

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | ActivityListView + ActivityRowView | b2f3712 | ActivityListView.swift, ActivityRowView.swift (neu) |
| 2 | App-Verdrahtung RootView TabView | c1d71cf | RootView.swift |

---

## Was wurde gebaut

### Task 1: ActivityListView + ActivityRowView

**ActivityListView (DASH-04 + DASH-05):**
- NavigationStack + `.listStyle(.insetGrouped)` + `.navigationTitle("Verlauf")`
- OBEN: "Gesamt (alle Zeit)" Section mit `allTimeStats` (DASH-04) — Ladeindikator waehrend `allTimeStats == nil`
- family-weiter Feed aus `activityService.todayEntries` nach Kalendertag gruppiert (DASH-05)
- Section-Header mit formatiertem Datum (`weekday.wide.day.month.wide`)
- Eintraege absteigend nach loggedAt sortiert (alle Familienmitglieder)
- `.swipeActions(edge: .trailing, allowsFullSwipe: false)` — NICHT .onDelete (Pitfall 5)
- `.confirmationDialog("Eintrag loeschen", titleVisibility: .visible)` + Bestaetigung vor Loeschen
- Leerstand: tray-Icon + "Noch keine Eintraege" + Body-Text (UI-SPEC Copywriting)
- `.task` laedt `fetchTodayData()` + `fetchAllTimeStats()` beim Erscheinen

**ActivityRowView:**
- HStack: SF Symbol (category.sfSymbol) in ringColor + VStack (Name + Dauer/Punkte) + Zeitstempel
- `displayName`: entry.title wenn gesetzt, sonst category.name, sonst "Aktivitaet"
- `ringColor`: systemRed (duty), systemGreen (leisure), systemBlue (fallback)
- `.accessibilityElement(children: .ignore)` + `.accessibilityLabel(...)` (UI-SPEC Accessibility Contract)
- `.frame(minHeight: 44)` iOS HIG Touch Target

### Task 2: App-Verdrahtung

**RootView.swift:**
- `authenticated(hasFamily: true)` Zweig ersetzt: `DashboardView()` → `TabView { DashboardView + ActivityListView }`
- Tab 1: DashboardView mit Label("Uebersicht", systemImage: "house.fill")
- Tab 2: ActivityListView mit Label("Verlauf", systemImage: "list.bullet")
- Kommentar dokumentiert currentFamilyId-Injection-Strategie (Option A via FamilyScoreApp.swift .onChange)

**FamilyScoreApp.swift (unveraendert — bereits vollstaendig aus Wave 2/Plan 04-03):**
- `@StateObject private var activityService = ActivityService()` — vorhanden
- `.environmentObject(activityService)` — vorhanden
- `.onChange(of: familyService.currentFamily?.id) { activityService.currentFamilyId = newFamilyId }` — vorhanden

---

## Build-Ergebnis / Test-Status

**Lokaler xcodebuild:** Nicht verfuegbar — macOS-Installation hat kein iOS Simulator Framework (`CoreSimulator.framework` fehlt).

**GitHub Actions CI:** Build-Run 26275314769 fehlgeschlagen wegen GitHub Billing-Blocker:
> "The job was not started because recent account payments have failed or your spending limit needs to be increased."

Dies ist ein externer Billing-Blocker, KEIN Code-Fehler. Der vorherige erfolgreiche CI-Run (26274221514) war auf Commit `322c507` — ALLE Aenderungen in Plan 04-03 wurden mit "success" gebaut und getestet.

**Statische Code-Analyse (durchgefuehrt):**
- Alle Acceptance Criteria via grep verifiziert (100% bestanden)
- MockActivityService.swift: `fetchAllTimeStats()` bereits implementiert — kein Protocol-Konformanz-Fehler
- ActivityServiceProtocol.swift: `allTimeStats: AllTimeStats?` Property vorhanden
- Keine .onDelete Verwendung in ActivityListView (grep bestaetigt)
- Alle @EnvironmentObject, TabItem, TabView Syntax korrekt

---

## Geraete-Checkpoint (Task 3)

**Status: WARTET AUF VERIFIKATION**

Der Geraete-Checkpoint (Task 3) erfordert manuelle Verifikation auf echtem iOS-Geraet. Alle 6 Success Criteria aus ROADMAP.md muessen bestaetigt werden:

| SC | Beschreibung | Status |
|----|-------------|--------|
| SC-1 | Aktivitaet in max 3 Taps loggen | Ausstehend |
| SC-2 | Eintrag fuer Kind-Profil erstellen | Ausstehend (Kind-UI nicht in Phase 4) |
| SC-3 | Eigenen Eintrag loeschen; Admin loescht fremden | Ausstehend |
| SC-4 | Ringe spiegeln heutige Aktivitaeten | Ausstehend |
| SC-5 | Familienvergleich zeigt alle Mitglieder | Ausstehend |
| SC-6 | Wochenbilanz + Wochensieger | Ausstehend |

---

## Deviations from Plan

### Beobachtungen ohne Aenderungsbedarf

**1. [Kein Eingriff] FamilyScoreApp.swift bereits fertig aus Wave 2**
- **Found during:** Task 2 Read
- **Issue:** Plan beschreibt, activityService muesse noch hinzugefuegt werden — war bereits in Plan 04-03 Wave 2 implementiert
- **Fix:** Keine Aenderung noetig. Verfuegbare Arbeit: nur RootView TabView-Wechsel
- **Auswirkung:** Task 2 war kleiner als geplant — nur RootView wurde modifiziert

**2. [Externer Blocker] GitHub Actions Billing**
- **Found during:** Task 2 Verifizierung
- **Issue:** CI kann nicht starten wegen Billing-Problem
- **Fix:** Nicht moeglich in diesem Kontext. Statische Analyse als Ersatz durchgefuehrt.
- **Status:** Deferred — xcodebuild test Ergebnis ausstehend bis Billing geloest

---

## Known Stubs

- `ActivityListView.groupedByDay` verwendet `activityService.todayEntries` — der Name "todayEntries" suggeriert Heute-Filter, aber die Property enthaelt tatsaechlich alle Eintraege (family-weit, ohne Datumsfilter in fetchTodayData — laut DASH-05 korrekt). Die Gruppenstruktur macht das transparent durch Section-Header pro Datum.

---

## Threat Surface Scan

- T-4-02: ActivityListView uebergibt nur `entry.id` an `deleteActivity()` — kein user_id-Parameter. RLS-Policy auf DB-Seite entscheidet. Korrekt implementiert (accepted per Plan).
- T-4-04: TabView nur sichtbar bei `.authenticated(hasFamily: true)` — unauthenticated → AuthFlowView. Korrekt implementiert.
- Keine neuen Netzwerk-Endpoints oder Auth-Pfade eingefuehrt.

---

## Self-Check

### Created Files
- [x] FamilyScore/FamilyScore/Views/ActivityLog/ActivityListView.swift
- [x] FamilyScore/FamilyScore/Views/ActivityLog/ActivityRowView.swift

### Modified Files
- [x] FamilyScore/FamilyScore/Views/RootView.swift (TabView)

### Commits
- [x] b2f3712 (Task 1: ActivityListView + ActivityRowView)
- [x] c1d71cf (Task 2: RootView TabView)

### Acceptance Criteria

**Task 1:**
- [x] swipeActions(edge: .trailing): GEFUNDEN
- [x] confirmationDialog: GEFUNDEN
- [x] "Noch keine Eintraege": GEFUNDEN
- [x] "Dieser Eintrag wird dauerhaft geloescht": GEFUNDEN
- [x] KEIN .onDelete: BESTAETIGT (nur in Kommentaren, nie als Methode)
- [x] ActivityRowView: GEFUNDEN
- [x] allTimeStats + fetchAllTimeStats: GEFUNDEN
- [x] sfSymbol + ringColor in ActivityRowView: GEFUNDEN
- [x] accessibilityElement + accessibilityLabel in ActivityRowView: GEFUNDEN

**Task 2:**
- [x] @StateObject private var activityService in FamilyScoreApp: GEFUNDEN
- [x] .environmentObject(activityService): GEFUNDEN
- [x] authService.startObserving() in .task (unveraendert): GEFUNDEN
- [x] TabView in RootView: GEFUNDEN
- [x] DashboardView() in RootView: GEFUNDEN
- [x] ActivityListView() in RootView: GEFUNDEN
- [x] currentFamilyId dokumentiert (via .onChange in FamilyScoreApp): GEFUNDEN

## Self-Check: PASSED (statisch — xcodebuild via CI ausstehend wegen Billing-Blocker)
