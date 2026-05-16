---
phase: 2
slug: 02-authentication
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-15
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (neues FamilyScoreTests-Target — Wave 0 erstellt) |
| **Config file** | `FamilyScore.xcodeproj` → Test-Target `FamilyScoreTests` |
| **Quick run command** | `xcodebuild build -scheme FamilyScore -destination "platform=iOS Simulator,name=iPhone 16" -quiet` |
| **Full suite command** | `xcodebuild test -scheme FamilyScore -destination "platform=iOS Simulator,name=iPhone 16"` |
| **Estimated runtime** | ~60 Sekunden |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild build -scheme FamilyScore -destination "platform=iOS Simulator,name=iPhone 16" -quiet`
- **After every plan wave:** Run `xcodebuild test -scheme FamilyScore -destination "platform=iOS Simulator,name=iPhone 16"`
- **Before `/gsd-verify-work`:** Full suite muss grün sein + alle 4 Requirements manuell auf Gerät verifiziert
- **Max feedback latency:** ~60 Sekunden

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 2-01-01 | 01 | 0 | AUTH-01, AUTH-04 | T-2-01 | XCTest-Target schlägt fehl bis Wave 0 abgeschlossen | setup | `xcodebuild build -scheme FamilyScore` | ❌ W0 | ⬜ pending |
| 2-02-01 | 02 | 1 | AUTH-01, AUTH-03 | T-2-02 | AppState.loading bis INITIAL_SESSION | integration | `xcodebuild test -scheme FamilyScore -only-testing FamilyScoreTests/AuthServiceTests` | ❌ W0 | ⬜ pending |
| 2-02-02 | 02 | 1 | AUTH-01 | T-2-03 | signInWithPassword mit falschen Credentials → Fehler | unit | `xcodebuild test -scheme FamilyScore -only-testing FamilyScoreTests/AuthServiceTests/testSignInWithWrongPassword` | ❌ W0 | ⬜ pending |
| 2-02-03 | 02 | 1 | AUTH-04 | T-2-04 | signOut → authStateChanges feuert SIGNED_OUT | integration | `xcodebuild test -scheme FamilyScore -only-testing FamilyScoreTests/AuthServiceTests/testSignOut` | ❌ W0 | ⬜ pending |
| 2-03-01 | 03 | 2 | AUTH-02 | T-2-05 | Nonce rawNonce (nicht SHA256) an Supabase übergeben | unit (mock) | `xcodebuild test -scheme FamilyScore -only-testing FamilyScoreTests/AuthServiceTests/testAppleNonce` | ❌ W0 | ⬜ pending |
| 2-03-02 | 03 | 2 | AUTH-02 | T-2-06 | Apple-Abbruch (canceled) → kein Fehler-Banner | unit | `xcodebuild test -scheme FamilyScore -only-testing FamilyScoreTests/AuthServiceTests/testAppleCancelNoError` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `FamilyScoreTests/` — XCTest-Target im Xcode-Projekt erstellen
- [ ] `FamilyScoreTests/AuthServiceTests.swift` — Unit + Integration Tests für AUTH-01, AUTH-04
- [ ] `FamilyScoreTests/Mocks/MockAuthService.swift` — Mock für Preview-Injektion und Unit-Tests
- [ ] Build-Verifikation: `xcodebuild build -scheme FamilyScore` muss 0 Errors/Warnings haben

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Sign in with Apple — echtes Gerät + Apple ID | AUTH-02 | ASAuthorizationController benötigt physisches Gerät und echte Apple ID; kein Simulator-Support | (1) App auf echtem Gerät starten (2) "Sign in with Apple" antippen (3) Biometrie/Passwort bestätigen (4) App muss zu authenticated-Placeholder navigieren |
| Session-Persistenz nach App-Kill | AUTH-03 | Keychain-Verhalten unterscheidet sich zwischen Simulator und echtem Gerät | (1) Einloggen (2) App im App Switcher killen (3) App neu starten (4) Login-Screen darf NICHT erscheinen — App muss direkt zu Placeholder navigieren |
| Apple-Name beim ersten Login gespeichert | AUTH-02 | Erster vs. zweiter Apple-Login unterschiedliches Verhalten | Frisch registrierter Apple-Account: `display_name` in `family_members` Tabelle muss den echten Namen enthalten (Supabase Dashboard prüfen nach Login) |

---

## Validation Sign-Off

- [ ] Alle Tasks haben `<automated>` verify oder Wave 0 Abhängigkeiten
- [ ] Sampling Continuity: keine 3 aufeinanderfolgenden Tasks ohne automated verify
- [ ] Wave 0 deckt alle MISSING (❌ W0) Referenzen ab
- [ ] Keine watch-mode Flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` im Frontmatter gesetzt

**Approval:** pending
