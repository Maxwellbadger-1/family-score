# Mac-Übergabe — Family Score

**Datum:** 2026-05-16  
**Status:** Phase 2 (Authentication) Code fertig auf Windows — Mac braucht Xcode-Setup + Gerät-Test  
**Repo:** https://github.com/Maxwellbadger-1/family-score.git (branch: master)

---

## 1. Repo klonen / aktualisieren

```bash
git clone https://github.com/Maxwellbadger-1/family-score.git
cd family-score
```

Oder falls schon geklont:
```bash
git pull origin master
```

---

## 2. Secrets.xcconfig anlegen (EINMALIG — nicht in Git)

Direkt im Terminal ausführen (erstellt die Datei automatisch):

```bash
cat > FamilyScore/Config/Secrets.xcconfig << 'EOF'
// Secrets.xcconfig — NICHT in Git einchecken (steht in .gitignore)
SUPABASE_URL_SECRET = https://amotertwccevkfowxvtk.supabase.co
SUPABASE_KEY_SECRET = sb_publishable_Z4uMbNC964CEUoEy14LEIQ_FW1yB9ca
EOF
```

⚠️ **Diese Zeilen nach dem Setup aus dieser Datei löschen.**

---

## 3. Projekt in Xcode öffnen

```
FamilyScore/FamilyScore.xcodeproj öffnen (NICHT .xcworkspace)
```

Signing-Team einstellen:  
**Xcode → FamilyScore Target → Signing & Capabilities → Team auswählen**

---

## 4. FamilyScoreTests-Target hinzufügen (Phase 2 — Wave 0)

Die Swift-Quelldateien liegen bereits im Repo, müssen aber als Xcode-Target registriert werden:

```
File → New → Target...
Template:         Unit Testing Bundle
Product Name:     FamilyScoreTests
Bundle ID:        com.familyscore.tests
Host Application: FamilyScore
Language:         Swift
```

Nach dem Erstellen prüfen:
- Target Navigator zeigt "FamilyScoreTests"
- Build Settings → Testing → Host Application = FamilyScore

Dann die **bereits vorhandenen** Swift-Dateien dem Target zuweisen:
- `FamilyScore/FamilyScoreTests/AuthServiceTests.swift` → Target: FamilyScoreTests
- `FamilyScore/FamilyScoreTests/Mocks/MockAuthService.swift` → Target: FamilyScoreTests

---

## 5. Sign in with Apple Capability aktivieren (Phase 2 — Wave 2)

```
Xcode → FamilyScore Target → Signing & Capabilities → + Capability → Sign in with Apple
```

Falls Fehlermeldung "requires paid developer account": Apple Developer Program Membership nötig.

---

## 6. Build prüfen

```bash
xcodebuild build \
  -project "FamilyScore/FamilyScore.xcodeproj" \
  -scheme FamilyScore \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  -quiet 2>&1 | grep -E "BUILD|error:"
# Erwartet: BUILD SUCCEEDED
```

---

## 7. Unit Tests laufen lassen

```bash
xcodebuild test \
  -project "FamilyScore/FamilyScore.xcodeproj" \
  -scheme FamilyScore \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  -only-testing FamilyScoreTests/AuthServiceTests 2>&1 | grep -E "passed|failed"
# Erwartet: 8 tests passed, 0 tests failed
```

---

## 8. Auf echtem iPhone testen (iOS 16+)

App auf echtes Gerät deployen. Dann diese 4 Requirements verifizieren:

### AUTH-01: E-Mail + Passwort
- Registrierung mit Testdaten → App zeigt "Willkommen!" (OnboardingPlaceholder)
- Login mit denselben Daten → gleicher Screen
- Login mit falschem Passwort → roter Fehler-Banner erscheint, kein Crash

### AUTH-02: Sign in with Apple
- Apple-Button tippen → Face ID / Passwort → OnboardingPlaceholder erscheint
- **Supabase Dashboard prüfen:** Authentication → Users → neuer User muss erscheinen
- **Abbruch-Test:** Apple-Dialog öffnen → "Abbrechen" → kein Fehler-Banner, Screen unverändert

### AUTH-03: Session-Persistenz nach App-Kill
- Mit E-Mail+Passwort einloggen
- App im App-Switcher nach oben wischen (killen)
- App neu starten
- Erwartet: kurzer Loading-Spinner, dann direkt OnboardingPlaceholder — KEIN Login-Screen

### AUTH-04: Ausloggen
- Im OnboardingPlaceholder "Ausloggen" tippen → sofort Login-Screen
- App killen und neu starten → Login-Screen (keine automatische Re-Session)

---

## 9. Ergebnis zurückmelden

Wenn alle 4 Requirements bestehen → in Claude Code eingeben:

```
AUTH verifiziert
```

Wenn etwas nicht funktioniert → beschreiben welches Requirement fehlt. Claude Code setzt die Phase 2 Verifikation dann fort und geht zu Phase 3 über.

---

## Aktueller Projektstand

| Phase | Status | Offene Mac-Schritte |
|-------|--------|---------------------|
| 1. Foundation | ✓ Code fertig | Xcode-Build + App-Group-Test auf Gerät (SC-1/SC-2) |
| 2. Authentication | Code fertig, Checkpoint | Schritte 4–9 oben |
| 3. Family Core | Geplant (4 Pläne) | — |
| 4–6 | Geplant | — |

**Phase 1 offene Punkte (SC-1/SC-2):** Beim ersten Xcode-Build bitte auch prüfen:
- App Group `group.com.familyscore` funktioniert (Xcode zeigt kein Signing-Fehler)
- Widget-Extension-Target baut fehlerfrei

---

## Wichtige Dateipfade

```
FamilyScore/FamilyScore/Models/AppState.swift          ← final (nicht ändern)
FamilyScore/FamilyScore/Services/AuthService.swift     ← Auth-Logik
FamilyScore/FamilyScore/Views/RootView.swift           ← App-Navigation
FamilyScore/FamilyScore/Views/Auth/                    ← Login/Register/Apple
FamilyScore/FamilyScore/FamilyScoreApp.swift           ← Entry Point
FamilyScore/FamilyScoreTests/AuthServiceTests.swift    ← Unit Tests
FamilyScore/Config/Secrets.xcconfig                    ← LOKAL, nicht in Git!
```
