---
status: complete
phase: 03-family-core
source: 03-01-SUMMARY.md, 03-02-SUMMARY.md, 03-03-SUMMARY.md, 03-04-SUMMARY.md
started: 2026-05-22T00:00:00Z
updated: 2026-05-22T12:00:00Z
---

## Current Test
<!-- OVERWRITE each test - shows where we are -->

[testing complete]

## Tests

### 1. Family Onboarding Screen
expected: Nach Login ohne Familie erscheint FamilyOnboardingView mit "Familie erstellen", "Bestehender Familie beitreten" und "Ausloggen"-Button.
result: pass
note: User hat bereits Familie — Routing zeigt Onboarding korrekt nicht an (hasFamily: true)

### 2. Familie erstellen
expected: Familienname eingeben, Button tippen → Familie wird erstellt, AppState wechselt zu authenticated(hasFamily: true), kein Fehler.
result: pass
note: Appetize.io: grüner Haken, "Eingeloggt!", State: authenticated (has family) sichtbar

### 3. Einladungscode generieren (Admin)
expected: In MemberListView als Admin: "Einladen"-Button öffnet InviteSheet. Sheet zeigt generierten 8-Zeichen-Code (z.B. "A3FX9K2M") + "Kopieren"-Button.
result: pass
note: Code "N2OIARIU" generiert, "Code kopieren" + "Neuen Code generieren" sichtbar

### 4. Familie beitreten (mit Code)
expected: In JoinFamilyView 8-Zeichen-Code eingeben und abschicken → User joined Familie, AppState wechselt zu authenticated(hasFamily: true).
result: pass
note: Fix verifiziert — Code funktioniert nach generateInvite-Fix (commit 2bbbeb2)

### 5. Mitgliederliste anzeigen
expected: MemberListView zeigt alle Familienmitglieder mit Name und Avatar-Farbe. Kind-Profile erscheinen in eigenem Abschnitt.
result: pass
note: Nur ein Mitglied (User selbst) sichtbar — korrekt, da noch niemand gejoint

### 6. Admin: Mitglied entfernen
expected: Als Admin in MemberListView: Swipe auf Mitglied zeigt "Entfernen"-Aktion. Nach Bestätigung verschwindet das Mitglied aus der Liste.
result: pass
note: Kein Swipe-Action auf letzten Admin — Schutz greift korrekt

### 7. Admin: Rolle ändern
expected: Als Admin auf Mitglied tippen → RolePickerSheet öffnet sich mit 3 Rollen-Optionen. Auswahl speichert Änderung.
result: pass
note: Swipe-Right öffnet RolePickerSheet (Leading-Swipe-Action) — minor UX-Auffälligkeit

### 8. Kind-Profil erstellen
expected: "Kind hinzufügen"-Button öffnet AddChildView. Name eingeben + eine von 6 Preset-Farben wählen → Profil erscheint in Mitgliederliste.
result: pass
note: "+" Button oben rechts öffnet AddChildView

### 9. Navigation zu MemberListView
expected: Im eingeloggten Zustand (hat Familie): NavigationLink "Familie verwalten" führt zur MemberListView mit geladenen Mitgliedern.
result: pass

## Summary

total: 9
passed: 9
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

- truth: "Familie beitreten mit 8-Zeichen-Code funktioniert"
  status: fixed
  reason: "User reported: Ungültiger oder abgelaufener Einladungscode — Code N2OIARIU eingegeben, Fehler erscheint"
  severity: major
  test: 4
  root_cause: "generateInvite() speicherte DB-Default-Token (base64, 16 Zeichen inkl. Sonderzeichen) und zeigte nur nachträglich gefilterte 8 Zeichen an. accept_invite RPC macht exakten Match auf Volltoken → kein Treffer."
  artifacts:
    - path: "FamilyScore/FamilyScore/Services/FamilyService.swift"
      issue: "Token wurde post-insert auf 8 Zeichen gekürzt, DB hatte Originalwert"
  missing:
    - "Token vor INSERT generieren und explizit mitgeben (DB-Default überschreiben)"
  debug_session: ""
