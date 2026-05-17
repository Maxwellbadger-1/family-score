---
phase: 3
plan: 4
subsystem: family-core
tags: [swiftui, rootview, environment-object, navigation, wiring]
dependency_graph:
  requires: [03-03-SUMMARY.md]
  provides: [FamilyService-injection, FamilyOnboardingView-routing, MemberListView-navigation]
  affects: [RootView.swift, FamilyScoreApp.swift]
tech_stack:
  added: []
  patterns: [NavigationStack, @StateObject injection, @EnvironmentObject propagation]
key_files:
  created: []
  modified:
    - FamilyScore/FamilyScore/Views/RootView.swift
    - FamilyScore/FamilyScore/FamilyScoreApp.swift
decisions:
  - FamilyService wird als @StateObject in FamilyScoreApp gehalten (gleiche Strategie wie AuthService) — Lebenszyklus vom Framework verwaltet, kein Singleton
  - NavigationStack in AuthenticatedPlaceholderView eingefuehrt damit NavigationLink zu MemberListView funktioniert (iOS 16 kompatibel)
metrics:
  duration: ~10min
  completed: 2026-05-17
---

# Phase 3 Plan 4: App-Verdrahtung (Wave 3) Summary

One-liner: FamilyService in App-Einstiegspunkt injiziert und RootView auf echte Phase-3-Views verdrahtet.

## Tasks

### Task 1: RootView.swift verdrahten (DONE)
**Commit:** `0bd8dc6`

Zwei Aenderungen in `FamilyScore/FamilyScore/Views/RootView.swift`:

1. `.authenticated(hasFamily: false)` zeigt jetzt `FamilyOnboardingView()` statt `OnboardingPlaceholderView()` — der echte Onboarding-Flow aus Phase 3 (Plan 03-03) ist damit aktiv.

2. `AuthenticatedPlaceholderView` erweitert:
   - `@EnvironmentObject private var familyService: FamilyService` hinzugefuegt
   - Body in `NavigationStack` eingewickelt (iOS 16 kompatibel)
   - `NavigationLink(destination: MemberListView())` mit Label "Familie verwalten" vor dem "Ausloggen"-Button eingefuegt

### Task 2: FamilyScoreApp.swift erweitern (DONE)
**Commit:** `8a5b4b8`

Zwei Aenderungen in `FamilyScore/FamilyScore/FamilyScoreApp.swift`:

1. `@StateObject private var familyService = FamilyService()` nach `authService` hinzugefuegt
2. `.environmentObject(familyService)` nach `.environmentObject(authService)` in der WindowGroup injiziert — FamilyService steht damit im gesamten View-Hierarchy zur Verfuegung

### Task 3: Geraete-Checkpoint (AUSSTEHEND — Human Verify)

**Status:** Checkpoint wartet auf manuelle Verifikation via Appetize.io

Die 5 Success Criteria von Phase 3 muessen verifiziert werden:

| SC | Kriterium | Testweg |
|----|-----------|---------|
| SC-1 | Erster User kann Familiengruppe erstellen, Admin-Rolle automatisch | Appetize.io |
| SC-2 | Admin generiert Invite-Token; zweiter User joined und sieht Familie sofort | Appetize.io (2 Sessions) |
| SC-3 | Admin entfernt Mitglied; Mitglied sieht keine Familiendaten mehr | Appetize.io + Supabase Dashboard |
| SC-4 | Admin aendert Rolle eines Mitglieds (Admin / Adult / Child-simplified) | Appetize.io |
| SC-5 | Jedes Mitglied hat sichtbares Profil mit Name und Avatar-Farbe; Kind-Profile im MemberList | Appetize.io |

**Naechster Schritt:** CI-Build abwarten (GitHub Actions), dann Appetize.io-Link aus Artifact laden und SC-1 bis SC-5 durchspielen.

## Build Verification

Kein lokales `xcodebuild` moeglich (Windows-only Entwicklungsumgebung). Build-Verifikation erfolgt ausschliesslich via CI (GitHub Actions, macOS-Runner). Nach Push wird CI automatisch gestartet:

```powershell
& "C:\Program Files\GitHub CLI\gh.exe" run list --limit 3
```

## Deviations from Plan

None — Plan exakt ausgefuehrt. Task 3 ist als Checkpoint dokumentiert und wartet auf Human-Verifikation.

## Known Stubs

- `AuthenticatedPlaceholderView` bleibt ein Placeholder — wird in Phase 4 durch `MainTabView` ersetzt. Der NavigationLink zu `MemberListView` ist intentional als Ueberbrueckung bis Phase 4.

## Self-Check: PASSED

- `0bd8dc6` in git log vorhanden
- `8a5b4b8` in git log vorhanden
- `FamilyScore/FamilyScore/Views/RootView.swift` enthaelt `FamilyOnboardingView()` und `NavigationStack`
- `FamilyScore/FamilyScore/FamilyScoreApp.swift` enthaelt `familyService` StateObject und environmentObject
