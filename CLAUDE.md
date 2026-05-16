# Family Score — Claude Code Guide

## Project

Native iPhone App (SwiftUI, iOS 16+) für Familien-Aktivitäts-Tracking mit Zeitgerechtigkeit-Visualisierung.
Backend: Supabase (PostgreSQL + Realtime + Auth), Free Tier.

## Planungsdokumente

- `.planning/PROJECT.md` — Projektziele, Requirements, Entscheidungen
- `.planning/REQUIREMENTS.md` — 36 v1-Requirements mit REQ-IDs
- `.planning/ROADMAP.md` — 6 Phasen, Erfolgskriterien, Fortschritt
- `.planning/STATE.md` — aktueller Projektstatus
- `.planning/research/` — Recherche: Stack, Features, Architektur, Pitfalls

## GSD Workflow

Dieses Projekt folgt dem GSD-Workflow:

1. `/gsd-discuss-phase N` — Phase besprechen und Kontext sammeln
2. `/gsd-plan-phase N` — Detailplan erstellen
3. `/gsd-execute-phase N` — Plan ausführen
4. `/gsd-verify-work N` — Ergebnisse validieren

**Aktuell:** Phase 1 (Foundation) ist als nächstes dran → `/gsd-discuss-phase 1`

## Kritische Architektur-Regeln

Diese Regeln stammen aus der Recherche und dürfen NICHT gebrochen werden:

### Supabase
- **RLS immer aktivieren** — jede Tabelle hat `family_id`-basierte Policies
- **RLS nur mit echtem JWT testen** — Supabase-Dashboard bypassed RLS, gibt kein Fehler zurück
- **Score NIEMALS als mutabler Wert speichern** — immer `SUM()` über `activity_entries`, kein `total_score`-Column
- **Supabase SDK NUR im Hauptapp-Target** — nie im Widget-Extension-Target (30MB Limit!)
- **Realtime stirbt im iOS-Hintergrund** — auf `scenePhase == .active` re-subscriben, bei Foreground immer REST-Fetch

### WidgetKit
- **App Group** muss im Apple Developer Portal für BEIDE Targets registriert sein
- **Datenaustausch** nur via `UserDefaults(suiteName: "group.com.familyscore")` — nie direkt Netzwerk im Widget
- **Nach Realtime-Update** → App schreibt in App Group → `WidgetCenter.shared.reloadAllTimelines()`
- Lock Screen Widgets (accessory*): iOS 16+
- Interaktive Widget-Buttons (AppIntents): iOS 17+

### Xcode-Projektstruktur
- **Secrets.xcconfig** immer in .gitignore — Supabase Anon Key darf nie in Git
- **FamilyScoreKit** — shared Swift Package für Code zwischen App und Widget Extension
- **App Group Entitlement** — in beiden Targets (App + Widget Extension) konfigurieren

### GitHub Actions / CI (Regeln aus wiederholten Fehlern)
- **`generic/platform=iOS Simulator` NUR für `build`** — für `test` IMMER konkreten Simulator: `platform=iOS Simulator,name=Any iOS Simulator Device`
- **SPM-Cache via `-clonedSourcePackagesDirPath ~/spm-packages`** — immer diesen Flag bei `build`, `test` und `resolvePackageDependencies` setzen; Caching-Key = `hashFiles('FamilyScore/project.yml')`
- **NIEMALS `rm -rf DerivedData`** als regulären CI-Schritt — das sabotiert jeden Cache
- **Einen einzigen Job** für Build + Test — zwei separate Jobs downloaden SPM-Pakete doppelt
- **Explicit `resolvePackageDependencies`** als eigenen Schritt vor dem Build — vermeidet Timeout-Fehler beim ersten Build-Schritt
- **XcodeGen via Homebrew cachen** — `actions/cache` auf `/usr/local/Cellar/xcodegen` mit fixem Cache-Key; nur installieren wenn Cache-Miss
- **xcpretty via gem cachen** — `~/.gem` cachen; vor `gem install` prüfen ob bereits installiert: `gem list xcpretty --installed --quiet || gem install xcpretty --no-document`
- **Secrets.xcconfig vor XcodeGen** erstellen — XcodeGen liest xcconfig-Referenzen; falscher Schritt-Order führt zu Build-Fehlern

## Tech Stack

| Layer | Technologie | Begründung |
|-------|-------------|------------|
| UI | SwiftUI (Swift 6, Xcode 16) | Nativ, Widgets, Apple Health-Style Design |
| Widgets | WidgetKit + AppIntents | Lock Screen + Home Screen Widgets |
| Charts | Swift Charts (nativ) | iOS 16+, keine Third-Party nötig |
| Backend | Supabase (supabase-swift v2.46.0) | Realtime + Auth + PostgreSQL, Free Tier |
| Local Cache | SwiftData (optional, iOS 17+) | Offline-Queue für Aktivitäten |
| Deployment | iOS 16.0 Minimum | Lock Screen Widgets |

## Design-Prinzipien

- **Apple Health/Fitness Ästhetik** — Ringe, Dark Mode, klare Charts, native iOS-Qualität
- **Kein Feature-Bloat** — lieber weniger, aber poliert
- **Kein AI-Sloppy-Code** — keine unnötigen KI-Features
- **3 Taps Maximum** — jede primäre Aktion in maximal 3 Taps erreichbar

## Score-System

- Punkte = Minuten × Kategorie-Multiplikator (konfigurierbar)
- Score-Berechnung: immer `SUM()` als Datenbankabfrage oder RPC — NIE client-side akkumuliert
- Kategorien: Haushalt, Hobby/Freizeit, Besorgungen, Arbeit/Schule (alle an-/abwählbar)

## Phasen-Übersicht

| Phase | Status | Kerninhalt |
|-------|--------|------------|
| 1. Foundation | Nicht gestartet | Xcode, App Group, Supabase Schema + RLS |
| 2. Authentication | Nicht gestartet | Email + Sign in with Apple |
| 3. Family Core | Nicht gestartet | Familiengruppe, Invites, Profile |
| 4. Activity Logging & Dashboard | Nicht gestartet | Core-Loop, Ringe, Score |
| 5. Real-time & Widgets | Nicht gestartet | Live-Sync, 5 Widget-Oberflächen |
| 6. Settings & Polish | Nicht gestartet | Admin-Settings, Kinder-UI, App Store |
