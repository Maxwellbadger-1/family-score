---
phase: 01-foundation
verified: 2026-05-15T12:00:00Z
status: human_needed
score: 3/5 must-haves verified
overrides_applied: 0
gaps:
  - truth: "App baut und laeuft auf einem echten Geraet mit App Target und Widget Extension Target"
    status: failed
    reason: "FamilyScore.xcodeproj existiert nicht im Repository — das Xcode-Projekt wurde niemals auf einem Mac erstellt. Alle Swift-Quelldateien und Entitlements sind vorhanden, aber ohne .xcodeproj kein Build moeglich."
    artifacts:
      - path: "FamilyScore/FamilyScore.xcodeproj/project.pbxproj"
        issue: "Datei fehlt vollstaendig — Xcode-Projekt wurde nie auf einem Mac angelegt"
    missing:
      - "FamilyScore.xcodeproj muss auf einem Mac in Xcode erstellt werden (File > New > Project)"
      - "Widget Extension Target FamilyScoreWidgetExtension muss in Xcode hinzugefuegt werden"
      - "xcconfig Config/Config.xcconfig muss dem Projekt als Configuration File zugewiesen werden"
      - "FamilyScoreKit als lokales SPM Package hinzufuegen (nur App Target)"
      - "supabase-swift v2.46.0 via SPM im App Target einbinden (NICHT Widget Extension)"
  - truth: "App Group Container ist von beiden Targets auf einem physischen Geraet zugaenglich"
    status: failed
    reason: "Setzt voraus dass das Xcode-Projekt existiert und auf einem echten Geraet deployed wurde. Ohne .xcodeproj kein Build, kein Device-Deploy."
    artifacts:
      - path: "FamilyScore/FamilyScore.xcodeproj"
        issue: "Existiert nicht"
    missing:
      - "Xcode-Projekt auf Mac erstellen (Blocker aus Gap 1)"
      - "App auf echtes Geraet deployen und [Phase1] App Group Test: PASS in Xcode Console bestaetigen"
human_verification:
  - test: "SC-1 + SC-2: Xcode Build und echtes Geraet"
    expected: |
      1. xcodebuild -project FamilyScore/FamilyScore.xcodeproj -scheme FamilyScore -destination 'platform=iOS Simulator,name=iPhone 16' build gibt BUILD SUCCEEDED aus
      2. App auf echtes iPhone deployen → Xcode Console zeigt [Phase1] App Group Test: PASS
      3. Xcode Console zeigt [Phase1] Supabase Connection PASS — families returned 0 rows
    why_human: "Erfordert Mac mit Xcode 16 und ein physisches iPhone. Windows-Entwicklungsumgebung kann xcodebuild nicht ausfuehren."
  - test: "SC-3: Swift-Client-RLS-Verifikation live"
    expected: |
      App im Simulator starten. Xcode Console zeigt:
      [Phase1] Supabase Connection PASS — families returned 0 rows (expected 0 with RLS, no auth)
      [Phase1] weekly_summaries table exists PASS — 0 rows
    why_human: "Erfordert laufende App mit Supabase-Verbindung und echten Keys in Secrets.xcconfig — nur auf Mac ausfuehrbar."
---

# Phase 1: Foundation — Verifikationsbericht

**Phasenziel:** Ein baubaeres, deploybaeres Xcode-Projekt-Shell, das sich mit Supabase verbindet und strukturell korrekt fuer alle zukuenftigen Arbeiten ist — App Group Entitlements auf Geraet provisioniert, Schema und RLS live, Secrets aus Git
**Verifiziert:** 2026-05-15T12:00:00Z
**Status:** human_needed (SC-1 und SC-2 koennen nicht automatisiert geprueft werden; SC-3 server-seitig bestaetigt, Swift-Client-Aufruf ausstehend)
**Re-Verifikation:** Nein — Erstverifikation

---

## Zielerreichung

### Beobachtbare Wahrheiten (Success Criteria)

| # | Wahrheit | Status | Nachweis |
|---|----------|--------|----------|
| SC-1 | App baut und laeuft auf echtem Geraet (App Target + Widget Extension) | FAILED | `FamilyScore.xcodeproj` fehlt im Repository — Xcode-Projekt wurde nicht auf Mac erstellt |
| SC-2 | App Group Container auf physischem Geraet von beiden Targets zugaenglich | FAILED | Setzt SC-1 voraus; ohne `.xcodeproj` kein Build, kein Device-Deploy |
| SC-3 | Supabase-Schema live (6 Tabellen, RLS, echte Policies) — verifiziert per Swift Client | PARTIAL | Schema via Supabase MCP bestaetigt: 6 Tabellen, RLS aktiv — Swift-Client-Aufruf auf Mac noch ausstehend |
| SC-4 | Secrets.xcconfig gitignored, Supabase Anon Key in keiner committed Datei | VERIFIED | `git check-ignore` bestaetigt; `git grep` gibt 0 Treffer; git-History sauber |
| SC-5 | FamilyScoreKit lokales Swift Package vorhanden, nur im App Target, Widget ohne Supabase SDK | VERIFIED | `Package.swift` und `WidgetData.swift` korrekt; kein `import Supabase` in Widget-Dateien |

**Ergebnis: 2/5 vollstaendig VERIFIED, 1/5 PARTIAL, 2/5 FAILED**

---

### Artefakt-Verifikation

| Artefakt | Erwartet | Status | Details |
|----------|----------|--------|---------|
| `FamilyScore/FamilyScore.xcodeproj/project.pbxproj` | Xcode-Projektdatei mit 2 Targets | MISSING | Verzeichnis `FamilyScore/` enthaelt: Config/, FamilyScore/, FamilyScoreKit/, FamilyScoreWidgetExtension/, supabase/ — kein .xcodeproj |
| `FamilyScore/FamilyScore/Resources/FamilyScore.entitlements` | App Group `group.com.familyscore` | VERIFIED | Datei vorhanden, enthaelt korrekt `group.com.familyscore` |
| `FamilyScore/FamilyScoreWidgetExtension/FamilyScoreWidgetExtension.entitlements` | App Group `group.com.familyscore` | VERIFIED | Datei vorhanden, enthaelt korrekt `group.com.familyscore` |
| `FamilyScore/Config/Config.xcconfig` | `#include "Secrets.xcconfig"`, SUPABASE_URL/KEY Injection | VERIFIED | Vorhanden mit korrektem Inhalt |
| `FamilyScore/Config/Secrets.xcconfig` | Gitignored, nicht getrackt | VERIFIED | `git check-ignore` bestaetigt; nicht in git ls-files |
| `FamilyScore/Config/Secrets.xcconfig.template` | Template fuer neue Entwickler | VERIFIED | Vorhanden |
| `FamilyScore/FamilyScoreKit/Package.swift` | SPM-Manifest, iOS 16+, keine externen Deps | VERIFIED | swift-tools-version 5.9, .iOS(.v16), kein `dependencies` Block |
| `FamilyScore/FamilyScoreKit/Sources/FamilyScoreKit/WidgetData.swift` | WidgetData (Sendable), appGroupIdentifier, placeholder | VERIFIED | Alle Exports korrekt; nur `import Foundation` |
| `FamilyScore/FamilyScore/Supabase.swift` | SupabaseClient Singleton, xcconfig-Injection, nur App Target | VERIFIED (Datei) / ORPHANED (Xcode-Einbindung) | Datei vorhanden, Bundle.main.object-Pattern korrekt; ob im App Target eingebunden: unbekannt ohne .xcodeproj |
| `FamilyScore/supabase/migrations/20260515_initial_schema.sql` | 6 Tabellen, 6x RLS, Trigger, kein total_score | VERIFIED | 6 `create table`, 6x `enable row level security`, `on_activity_entry_change` Trigger, kein `total_score` Column |
| `.gitignore` | Enthaelt `Secrets.xcconfig` | VERIFIED | Eintrag in Zeile 17 bestaetigt |
| `FamilyScore/FamilyScore/Resources/Info.plist` | `$(SUPABASE_URL)` und `$(SUPABASE_KEY)` | VERIFIED | Beide Build-Setting-Injections vorhanden |

---

### Key-Link-Verifikation

| Von | Zu | Via | Status | Details |
|-----|----|-----|--------|---------|
| `Config/Config.xcconfig` | Xcode Projekt-Konfigurationen | `baseConfigurationReference` in project.pbxproj | NOT_WIRED | `.xcodeproj` fehlt — Zuweisung kann nicht geprueft werden |
| `FamilyScore.entitlements` | FamilyScore App Target | `CODE_SIGN_ENTITLEMENTS` in project.pbxproj | NOT_WIRED | `.xcodeproj` fehlt |
| `FamilyScoreWidgetExtension.entitlements` | Widget Extension Target | `CODE_SIGN_ENTITLEMENTS` in project.pbxproj | NOT_WIRED | `.xcodeproj` fehlt |
| `Config/Secrets.xcconfig` | `Info.plist` | xcconfig Build-Setting-Injection | PARTIAL | Info.plist enthaelt `$(SUPABASE_URL)` korrekt; xcconfig-Zuweisung zum Projekt fehlt (kein .xcodeproj) |
| `Supabase.swift` | Supabase Cloud PostgreSQL | `SupabaseClient(supabaseURL:supabaseKey:)` via Bundle.main | PARTIAL | Code korrekt; ob SPM Package im App Target eingebunden ist, kann ohne .xcodeproj nicht geprueft werden |
| `20260515_initial_schema.sql` | Supabase Cloud DB | `supabase db push` | WIRED | Schema via Supabase MCP live angewendet (3 Migrationen); SC-03-SUMMARY bestaetigt alle 6 Tabellen live |

---

### Datenfluss-Trace (Level 4)

Nicht anwendbar fuer Phase 1 — keine UI-Komponenten die dynamische Daten rendern. Die Phase liefert Infrastruktur-Artefakte (Schema, Package, Konfiguration), keine datenbindenden Views.

---

### Verhaltens-Spot-Checks

| Verhalten | Befehl | Ergebnis | Status |
|-----------|--------|----------|--------|
| Secrets.xcconfig gitignored | `git check-ignore -v FamilyScore/Config/Secrets.xcconfig` | `.gitignore:17:Secrets.xcconfig FamilyScore/Config/Secrets.xcconfig` | PASS |
| Kein Supabase-Key in Swift-Dateien | `git grep "supabase.co" *.swift *.plist *.xcconfig` | Kein Output (Exit 1 = keine Treffer) | PASS |
| Keine git-History mit Supabase-URL | `git log --all -S "supabase.co" -- *.swift *.plist *.xcconfig` | Kein Output | PASS |
| appGroupIdentifier korrekt | `grep appGroupIdentifier WidgetData.swift` | `public let appGroupIdentifier = "group.com.familyscore"` | PASS |
| Kein `import Supabase` in Widget Extension | grep auf `FamilyScoreWidgetExtension/*.swift` | Kein Output | PASS |
| Package.swift ohne externe Deps | `grep supabase Package.swift` | Kein Output | PASS |
| `.xcodeproj` existiert | `ls FamilyScore/*.xcodeproj` | Nicht gefunden | FAIL |
| 6 Tabellen in SQL-Migration | `grep "^create table public" *.sql` | 6 Treffer: families, family_members, category_config, activity_entries, family_invites, weekly_summaries | PASS |
| 6x RLS in SQL-Migration | `grep "enable row level security" *.sql` | 6 Treffer | PASS |
| Kein `total_score` Column | `grep "total_score" *.sql` | Kein Output | PASS |

---

### Anti-Pattern-Befunde

| Datei | Zeile | Pattern | Schwere | Auswirkung |
|-------|-------|---------|---------|-----------|
| `FamilyScore/FamilyScoreApp.swift` | 31-44 | `verifySupabaseConnection()` nur in `#if DEBUG` | Info | Korrekt — Verifikationscode ist Debug-only, wird nicht in Production-Build eingebunden |
| `FamilyScore/FamilyScoreWidgetExtension/FamilyScoreWidget.swift` | 36 | `Text("Family Score")` als Widget-Body | Info | Erwarteter Stub fuer Phase 1 — Widget-UI kommt in Phase 5 |
| Kein `.xcodeproj` im Repository | — | Fehlendes Kernartefakt | Blocker | Kein Build moeglich ohne Xcode-Projektdatei. Alle anderen Dateien sind korrekt aber ohne Xcode-Integration nicht nutzbar |

---

### Menschliche Verifikation erforderlich

#### 1. SC-1 + SC-2: Xcode Build auf Mac und echtes Geraet

**Test:**
1. Mac mit Xcode 16 starten
2. Xcode-Projekt erstellen: File > New > Project > iOS App, Product Name: `FamilyScore`, Bundle ID: `com.familyscore`, iOS 16.0
3. Widget Extension hinzufuegen: File > New > Target > Widget Extension, Name: `FamilyScoreWidgetExtension`, Bundle ID: `com.familyscore.widgets`
4. App Group in beiden Targets konfigurieren: Signing & Capabilities > App Groups > `group.com.familyscore`
5. `Config/Config.xcconfig` als Configuration File fuer Debug und Release zuweisen
6. `FamilyScoreKit` als lokales Package hinzufuegen (beide Targets)
7. `supabase-swift` v2.46.0 via SPM hinzufuegen (NUR App Target)
8. Secrets.xcconfig mit echten Supabase-Werten befuellen (aus Supabase Dashboard: https://amotertwccevkfowxvtk.supabase.co)
9. `xcodebuild -project FamilyScore.xcodeproj -scheme FamilyScore -destination 'platform=iOS Simulator,name=iPhone 16' build` ausfuehren

**Erwartet:** `BUILD SUCCEEDED` im Terminal-Output

**Fuer SC-2 (echtes Geraet):**
- App auf iPhone deployen
- Xcode Console: `[Phase1] App Group Test: PASS`

**Warum menschliche Verifikation:** Mac mit Xcode 16 erforderlich. Windows-Umgebung kann `.xcodeproj` nicht erstellen und `xcodebuild` nicht ausfuehren.

#### 2. SC-3: Swift-Client-RLS-Verifikation

**Test:**
Nach SC-1 App im Simulator oder auf Geraet starten.

**Erwartet:** Xcode Console zeigt:
```
[Phase1] Supabase Connection PASS — families returned 0 rows (expected 0 with RLS, no auth)
[Phase1] weekly_summaries table exists PASS — 0 rows
[Phase1] RLS appears active — anon user sees 0 rows (correct RLS behavior)
```

**Warum menschliche Verifikation:** Erfordert laufende iOS App mit Supabase-Verbindung. Server-seitige RLS-Aktivierung ist bestaetigt (via Supabase MCP), aber der in SC-3 geforderte Swift-Client-Aufruf-Nachweis ist nur auf Mac ausfuehrbar.

---

## Lueckenzusammenfassung

**Wurzelursache beider Gaps:** Das Xcode-Projekt (`FamilyScore.xcodeproj`) wurde nie auf einem Mac erstellt. Die Phase-1-Plaene waren bewusst so konzipiert, dass Swift-Quelldateien, Entitlements, xcconfig und SQL-Migration auf Windows vorbereitet werden konnten — die Xcode-GUI-Schritte (Projekt anlegen, Targets konfigurieren, Packages einbinden) wurden als "offene Punkte" in allen drei SUMMARY-Dateien dokumentiert und sind explizit als "Mac erforderlich" markiert.

**Was fehlt (ein einziger Blocker mit mehreren Teilschritten):**
- Mac mit Xcode 16 aufsetzen
- Xcode-Projekt anlegen und konfigurieren (Anleitung in `01-01-SUMMARY.md` Abschnitt "Manuelle Xcode-Schritte")
- `supabase-swift` SPM einbinden (nur App Target)
- Secrets.xcconfig mit echten Keys befuellen
- Build ausfuehren und `[Phase1] Supabase Connection PASS` in Console bestaetigen

**SC-4 (Secrets) und SC-5 (FamilyScoreKit) sind vollstaendig VERIFIED** und blockieren nichts.

**SC-3 (Supabase-Schema)** ist server-seitig bestaetigt. Der spezifische Nachweis via Swift-Client (wie in SC-3 gefordert) steht noch aus und ist an denselben Mac-Build-Schritt gekoppelt.

---

_Verifiziert: 2026-05-15T12:00:00Z_
_Verifizierer: Claude (gsd-verifier)_
