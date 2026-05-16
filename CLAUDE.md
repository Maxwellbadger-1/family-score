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

## Windows-Entwicklungsworkflow (CI-First)

Der Entwickler arbeitet **ausschließlich auf Windows 11** — kein lokales Xcode, kein iOS Simulator. Alle Builds und Tests laufen über GitHub Actions auf einem macOS-Runner.

### Lokaler Entwicklungsloop

1. Code schreiben/ändern (Claude Code auf Windows)
2. `git push origin master` → CI startet automatisch
3. CI-Status prüfen:
   ```powershell
   & "C:\Program Files\GitHub CLI\gh.exe" run list --limit 3
   ```
4. Logs bei Fehler:
   ```powershell
   & "C:\Program Files\GitHub CLI\gh.exe" run view <ID> --log-failed
   ```
5. App-Artifact oder Appetize.io prüfen (s. u.)

> **gh CLI Pfad:** `C:\Program Files\GitHub CLI\gh.exe` — ist NICHT im Standard-PATH, immer absoluten Pfad verwenden.

### Wie wird getestet?

#### Unit Tests → Automatisch via CI
- Alle `XCTest`-Tests laufen bei jedem Push auf dem macOS-Runner
- Ergebnis: GitHub Actions → Step "Run Unit Tests"
- Fehler lesen: `gh run view <ID> --log-failed`
- Schreibe Tests immer gegen Mocks (kein echter Supabase-Call in Tests!)

#### UI / Funktionstest → Appetize.io
- CI baut die `.app` und lädt sie auf Appetize.io hoch (falls `APPETIZE_API_TOKEN` Secret gesetzt)
- Appetize.io simuliert ein iPhone im Browser — kein Mac nötig
- Für alle sichtbaren Flows testbar: Navigation, Auth-Formulare, Dashboard, Aktivitäts-Logging
- **Sign in with Apple** ist in Appetize **nicht** vollständig testbar (kein echter Apple-ID-Flow)

#### "Geräte-Checkpoint" in den Phasen = was ist gemeint?
Jede Phase hat einen "Geräte-Checkpoint" als letzten Plan. Da kein Mac verfügbar ist, gilt folgende Abstufung:

| Was zu testen ist | Wie |
|---|---|
| App startet, Navigation, Formulare, Auth-E-Mail | Appetize.io (Browser, kein Gerät nötig) |
| Supabase-Verbindung, RLS, Datenbank-Writes | Supabase Dashboard + CI Unit Tests |
| Sign in with Apple (echter Flow) | Sideloadly → physisches iPhone |
| App Group / Widget-Datenaustausch | Sideloadly → physisches iPhone |
| Lock Screen Widgets auf Gerät | Sideloadly → physisches iPhone |
| App Store Submission | GitHub Actions + fastlane (macOS-Runner signiert + uploaded) |

**Sideloading auf Windows (kein Mac nötig):** [Sideloadly](https://sideloadly.io/) installiert die `.ipa` aus den CI-Artifacts direkt aufs iPhone über USB. Mit Apple Developer Account: unbegrenzte Gültigkeit. Mit kostenloser Apple ID: 7 Tage (dann neu installieren).

**App Store ohne Mac:** GitHub Actions (macOS-Runner) + `fastlane match` + `fastlane deliver` — Zertifikate in verschlüsseltem Git-Repo, Upload vollautomatisch aus CI. Kein lokaler Mac benötigt. Setup erfolgt in Phase 6.

---

## GSD Workflow

Dieses Projekt folgt dem GSD-Workflow:

1. `/gsd-discuss-phase N` — Phase besprechen und Kontext sammeln
2. `/gsd-plan-phase N` — Detailplan erstellen
3. `/gsd-execute-phase N` — Plan ausführen
4. `/gsd-verify-work N` — Ergebnisse validieren

**Aktuell:** Phase 2 (Authentication) läuft, Plan 02-03 Task 3 wartet auf Appetize.io-Verifikation → nächster Schritt: Appetize.io testen oder Phase 3 starten

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
- **`generic/platform=iOS Simulator` NUR für `build`** — für `test` IMMER echten Simulator per UDID (python3-Script im workflow ermittelt ihn dynamisch); `Any iOS Simulator Device` ohne OS-Version hängt
- **SPM-Cache via `-clonedSourcePackagesDirPath ~/spm-packages`** — immer diesen Flag bei `build`, `test` und `resolvePackageDependencies` setzen; Caching-Key = `hashFiles('FamilyScore/project.yml')`
- **NIEMALS `rm -rf DerivedData`** als regulären CI-Schritt — das sabotiert jeden Cache
- **Einen einzigen Job** für Build + Test — zwei separate Jobs downloaden SPM-Pakete doppelt
- **Explicit `resolvePackageDependencies`** als eigenen Schritt vor dem Build — vermeidet Timeout-Fehler beim ersten Build-Schritt
- **Secrets.xcconfig vor XcodeGen** erstellen — XcodeGen liest xcconfig-Referenzen; falscher Schritt-Order führt zu Build-Fehlern

### XCTest / Test-Architektur (Regeln aus wiederholten Fehlern)
- **IMMER `XCTestConfigurationFilePath` prüfen** vor Supabase-Verbindungen im App-Entry-Point — Supabase hängt in CI 227s auf `placeholder.supabase.co` und crasht den Test-Host mit `signal trap`:
  ```swift
  guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
  await authService.startObserving()
  ```
- **Test-Host crasht mit `signal trap`** = externe Verbindung blockiert Main-Thread oder TCP-Timeout tötet Bootstrap — NICHT ein Compilation-Fehler
- **`Bundle.main` im Test-Context** = App-Bundle (nicht Test-Bundle) — xcconfig-Werte werden korrekt substituiert, ABER Netzwerk-Calls mit Placeholder-URLs hängen
- **Unit-Tests sollen NIE echte Supabase-Calls machen** — immer `MockAuthService`/Protokoll-Abstraktion nutzen; der globale `supabase`-Singleton in `Supabase.swift` darf in Tests nie initialisiert werden

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
| 1. Foundation | ✅ Abgeschlossen (2026-05-15) | Xcode, App Group, Supabase Schema + RLS |
| 2. Authentication | 🔄 In Progress (Plan 02-03 Checkpoint) | Email + Sign in with Apple |
| 3. Family Core | ⏳ Bereit | Familiengruppe, Invites, Profile |
| 4. Activity Logging & Dashboard | ⏳ Wartet auf Phase 3 | Core-Loop, Ringe, Score |
| 5. Real-time & Widgets | ⏳ Wartet auf Phase 4 | Live-Sync, 5 Widget-Oberflächen |
| 6. Settings & Polish | ⏳ Wartet auf Phase 5 | Admin-Settings, Kinder-UI, App Store via fastlane CI |
