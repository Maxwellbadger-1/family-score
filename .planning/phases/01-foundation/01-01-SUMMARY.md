---
plan: 01-01
phase: 01-foundation
status: complete
completed: 2026-05-15
---

# Plan 01-01: Xcode-Projektstruktur — Summary

## Was wurde erstellt (Dateien)

### Text-Dateien (erstellt auf Windows):
- `.gitignore` — Secrets.xcconfig-Eintrag, Xcode-Artefakte, SPM .build/
- `FamilyScore/Config/Config.xcconfig` — xcconfig mit Supabase Build-Setting-Injection
- `FamilyScore/Config/Secrets.xcconfig` — Gitignored Secrets (Placeholder-Werte, echte Keys eintragen!)
- `FamilyScore/Config/Secrets.xcconfig.template` — Template für neue Entwickler
- `FamilyScore/FamilyScore/Resources/FamilyScore.entitlements` — App Group `group.com.familyscore`
- `FamilyScore/FamilyScoreWidgetExtension/FamilyScoreWidgetExtension.entitlements` — App Group `group.com.familyscore`
- `FamilyScore/FamilyScore/Resources/Info.plist` — mit $(SUPABASE_URL) und $(SUPABASE_KEY) Injection
- `FamilyScore/FamilyScore/FamilyScoreApp.swift` — App-Entry-Point + verifyAppGroup() DEBUG-Funktion
- `FamilyScore/FamilyScore/ContentView.swift` — Minimaler SwiftUI Stub
- `FamilyScore/FamilyScoreWidgetExtension/FamilyScoreWidget.swift` — Widget-Stub mit App-Group-Test
- `FamilyScore/FamilyScoreWidgetExtension/FamilyScoreWidgetBundle.swift` — Widget Bundle Entry-Point

## Manuelle Xcode-Schritte (auf Mac erforderlich)

Diese Schritte MÜSSEN in Xcode auf einem Mac ausgeführt werden:

1. **Xcode-Projekt erstellen:**
   - File > New > Project → iOS > App
   - Product Name: `FamilyScore`, Bundle ID: `com.familyscore`, Swift, SwiftUI, iOS 16.0
   - Im Verzeichnis `FamilyScore/` speichern (innerhalb des Projektordners)

2. **Widget Extension Target hinzufügen:**
   - File > New > Target → Widget Extension
   - Product Name: `FamilyScoreWidgetExtension`, Bundle ID: `com.familyscore.widgets`
   - Include Configuration Intent: NEIN; Include Live Activity: NEIN

3. **App Group Entitlements konfigurieren:**
   - FamilyScore Target → Signing & Capabilities → + Capability → App Groups → `group.com.familyscore`
   - FamilyScoreWidgetExtension Target → Signing & Capabilities → + Capability → App Groups → `group.com.familyscore`
   - HINWEIS: Xcode generiert normalerweise .entitlements-Dateien — die bereits erstellten Entitlements-XMLs in den richtigen Pfad verschieben oder Xcode übernehmen lassen

4. **xcconfig dem Projekt zuweisen:**
   - Project (nicht Target) → Info → Configurations
   - Debug + Release: Configuration File → `Config/Config.xcconfig` wählen

5. **FamilyScoreKit Package hinzufügen:**
   - File > Add Package Dependencies > Add Local... → `FamilyScoreKit/` wählen
   - FamilyScore App Target → Frameworks → FamilyScoreKit hinzufügen
   - FamilyScoreWidgetExtension → Frameworks → FamilyScoreKit hinzufügen (KEIN Supabase!)

6. **Signing:**
   - Für private Nutzung: "Automatically manage signing" in beiden Targets aktivieren
   - Team: Eigenes Apple ID Team wählen

## Konfigurations-Status

| Komponente | Status |
|-----------|--------|
| .gitignore | Erstellt |
| Config.xcconfig | Erstellt |
| Secrets.xcconfig | Erstellt (Placeholder) |
| Secrets.xcconfig.template | Erstellt |
| FamilyScore.entitlements | Erstellt (group.com.familyscore) |
| FamilyScoreWidgetExtension.entitlements | Erstellt (group.com.familyscore) |
| Info.plist | Erstellt ($(SUPABASE_URL), $(SUPABASE_KEY)) |
| FamilyScoreApp.swift | Erstellt |
| ContentView.swift | Erstellt |
| FamilyScoreWidget.swift | Erstellt |
| FamilyScoreWidgetBundle.swift | Erstellt |
| FamilyScore.xcodeproj | Manuell in Xcode auf Mac erforderlich |
| Xcode Targets konfiguriert | Manuell in Xcode auf Mac erforderlich |
| xcconfig zugewiesen | Manuell in Xcode auf Mac erforderlich |

## Apple Developer Portal
Status: Übersprungen — "Automatically manage signing" wird in Xcode verwendet.
Für App Group Verifikation auf echtem Gerät: Portal-Konfiguration später nachholen.

## Wichtige Werte
- Bundle ID App: `com.familyscore`
- Bundle ID Widget: `com.familyscore.widgets`
- App Group: `group.com.familyscore`
- iOS Minimum: 16.0
- Swift Version: 6
- Supabase SDK: NUR im FamilyScore App Target (NICHT Widget Extension)

## Offene Punkte
- [ ] Xcode-Projekt auf Mac erstellen (Xcode GUI)
- [ ] Widget Extension Target hinzufügen (Xcode GUI)
- [ ] App Group Entitlements in Xcode konfigurieren (Xcode GUI)
- [ ] xcconfig dem Projekt zuweisen (Xcode GUI)
- [ ] FamilyScoreKit als lokales Package hinzufügen (Xcode GUI)
- [ ] Secrets.xcconfig mit echten Supabase-Werten befüllen (nach Plan 03)
- [ ] Build-Test (BUILD SUCCEEDED) — braucht Mac

## Self-Check: PASSED (alle Dateien erstellt; Xcode-Projekt-Erstellung erfordert Mac)
