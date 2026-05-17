---
phase: 03-family-core
plan: "03"
subsystem: family-views
tags: [swiftui, ios16, family-onboarding, member-management, views]
dependency_graph:
  requires: ["03-02-PLAN"]
  provides: ["FamilyOnboardingView", "CreateFamilyView", "JoinFamilyView", "MemberListView", "InviteSheet", "RolePickerSheet", "AddChildView"]
  affects: ["RootView", "03-04-PLAN"]
tech_stack:
  added: []
  patterns: ["@EnvironmentObject", "NavigationStack", ".task{}", "swipeActions", "UIPasteboard", "FocusState", "Sheet presentation"]
key_files:
  created:
    - FamilyScore/FamilyScore/Views/Family/FamilyOnboardingView.swift
    - FamilyScore/FamilyScore/Views/Family/CreateFamilyView.swift
    - FamilyScore/FamilyScore/Views/Family/JoinFamilyView.swift
    - FamilyScore/FamilyScore/Views/Family/MemberListView.swift
    - FamilyScore/FamilyScore/Views/Family/InviteSheet.swift
    - FamilyScore/FamilyScore/Views/Family/RolePickerSheet.swift
    - FamilyScore/FamilyScore/Views/Family/AddChildView.swift
  modified: []
decisions:
  - "Color(hex:) Extension in MemberListView.swift als einzige Definition — alle anderen Views im selben Modul nutzen sie implizit"
  - "currentUserIsAdmin basiert vorlaeufig auf 'irgendein Member ist Admin'; TODO Phase 4: echten currentUser.id Vergleich"
  - "RolePickerSheet ohne eigenen #Preview-Block (benoetigte FamilyMember-Instanz nicht einfach mockbar); beide anderen Sheets haben Previews"
metrics:
  duration: "15min"
  completed: "2026-05-17"
  tasks_completed: 2
  files_created: 7
---

# Phase 3 Plan 03: Family Views Summary

7 SwiftUI-Views fuer Familiengruppen-Onboarding und Mitgliederverwaltung mit Apple Health Aesthetik, iOS 16 kompatibel via @EnvironmentObject.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Onboarding-Views | fac8d79 | FamilyOnboardingView.swift, CreateFamilyView.swift, JoinFamilyView.swift |
| 2 | Mitglieder-Views | 3024252 | MemberListView.swift, InviteSheet.swift, RolePickerSheet.swift, AddChildView.swift |

## Deliverables

### View-Dateien (7 Dateien)

| Datei | Zweck | Schluesselfunktion |
|-------|-------|-------------------|
| FamilyOnboardingView.swift | Einstieg fuer User ohne Familie | NavigationStack mit 2 NavigationLinks + Ausloggen |
| CreateFamilyView.swift | Familie erstellen | createFamily() -> refreshFamilyStatus() |
| JoinFamilyView.swift | Bestehender Familie beitreten | joinFamily() -> refreshFamilyStatus(), 8-Zeichen-Code-Input |
| MemberListView.swift | Mitglieder + Kind-Profile anzeigen | .task{} Daten laden, swipeActions fuer Admin |
| InviteSheet.swift | Einladungscode generieren | generateInvite() + UIPasteboard Kopieren |
| RolePickerSheet.swift | Rolle eines Mitglieds aendern | changeMemberRole() mit 3-Rollen-Auswahl |
| AddChildView.swift | Kind-Profil ohne Login erstellen | createChildProfile() + 6 Preset-Farben |

### iOS 16 Kompatibilitaet

- @EnvironmentObject (nicht @Observable — iOS 17+): bestaetigt, kein @Observable in allen 7 Dateien
- ObservableObject Pattern: durchgaengig in FamilyService + AuthService
- NavigationStack: iOS 16+ kompatibel
- .task{}: iOS 15+ kompatibel

### refreshFamilyStatus-Verknuepfung

- CreateFamilyView: `await authService.refreshFamilyStatus()` nach `familyService.createFamily()` — bestaetigt
- JoinFamilyView: `await authService.refreshFamilyStatus()` nach `familyService.joinFamily()` — bestaetigt
- Mechanismus: refreshFamilyStatus() prueft family_members-Tabelle neu -> AppState wechselt zu .authenticated(hasFamily: true)

### Build-Status

Windows-Umgebung: kein lokales xcodebuild verfuegbar. Build-Verifikation erfolgt via CI (GitHub Actions) beim naechsten Push. Alle Views verwenden nur Standard-SwiftUI-APIs ohne externe Abhaengigkeiten.

## Deviations from Plan

None - Plan exakt wie spezifiziert ausgefuehrt. Alle 7 Dateien mit den vorgesehenen Patterns erstellt.

## Known Stubs

- **currentUserIsAdmin in MemberListView.swift**: Prueft nur ob IRGENDEIN Member Admin ist (nicht ob der AKTUELLE User Admin ist). Grund: Phase 3 hat keinen direkten Zugriff auf currentUser.id ohne Supabase-Call in der View. Plan dokumentiert dieses TODO explizit fuer Phase 4. Admin-Buttons sind nur UI — serverseitige Sicherheit liegt in den SECURITY DEFINER RPCs.

## Threat Flags

Keine neuen Bedrohungsflaechen ausserhalb des Plans. T-3-08, T-3-09, T-3-10 wie im Plan dokumentiert und akzeptiert/mitigiert.

## Self-Check: PASSED

- FamilyScore/FamilyScore/Views/Family/FamilyOnboardingView.swift: FOUND
- FamilyScore/FamilyScore/Views/Family/CreateFamilyView.swift: FOUND
- FamilyScore/FamilyScore/Views/Family/JoinFamilyView.swift: FOUND
- FamilyScore/FamilyScore/Views/Family/MemberListView.swift: FOUND
- FamilyScore/FamilyScore/Views/Family/InviteSheet.swift: FOUND
- FamilyScore/FamilyScore/Views/Family/RolePickerSheet.swift: FOUND
- FamilyScore/FamilyScore/Views/Family/AddChildView.swift: FOUND
- Commit fac8d79: FOUND (Task 1)
- Commit 3024252: FOUND (Task 2)
