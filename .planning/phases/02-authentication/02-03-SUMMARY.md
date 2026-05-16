---
phase: 02-authentication
plan: "03"
subsystem: auth
tags: [supabase, swiftui, sign-in-with-apple, nonce, cryptokit, ios16, environmentobject, stateobject]

dependency_graph:
  requires:
    - phase: 02-02
      provides: AuthService (ObservableObject), LoginView, RootView, AppState routing
    - phase: 02-01
      provides: AppState enum, MockAuthService, AuthServiceTests stubs
  provides:
    - SignInWithAppleView (vollstaendiger Nonce-Fluss: rawNonce→Supabase, sha256(rawNonce)→Apple)
    - LoginView mit Apple-Sign-In-Button (Trennlinie "oder" + SignInWithAppleView)
    - FamilyScoreApp.swift als vollstaendiger Auth-Entry-Point (@StateObject + .task + .environmentObject)
  affects:
    - 03-family-core (FamilyScoreApp.swift ist jetzt vollstaendig; Phase 3 erweitert OnboardingPlaceholderView)

tech-stack:
  added:
    - AuthenticationServices (ASAuthorizationController, SignInWithAppleButton)
    - CryptoKit (SHA256 fuer Nonce-Hash)
  patterns:
    - SHA256-Nonce-Fluss: SecRandomCopyBytes rawNonce, sha256(rawNonce) an Apple, rawNonce an Supabase
    - ASAuthorizationError.canceled wird still ignoriert (kein Error-Banner bei Abbruch)
    - fullName-Persistenz via supabase.auth.update() direkt nach erstem Apple-Login
    - @StateObject AuthService in App-Root, .task auf WindowGroup-Level fuer INITIAL_SESSION-Garantie
    - .environmentObject(authService) im App-Root für gesamte View-Hierarchy

key-files:
  created:
    - FamilyScore/FamilyScore/Views/Auth/SignInWithAppleView.swift
  modified:
    - FamilyScore/FamilyScore/Views/Auth/LoginView.swift (Trennlinie + SignInWithAppleView eingefuegt)
    - FamilyScore/FamilyScore/FamilyScoreApp.swift (vollstaendig ersetzt: @StateObject + RootView + .task)

key-decisions:
  - "rawNonce an Supabase signInWithIdToken, sha256(rawNonce) an Apple request.nonce — NIEMALS vertauschen (Pitfall 3)"
  - "ASAuthorizationError.canceled wird mit break behandelt — kein authError gesetzt (Pitfall 5)"
  - "fullName nach erstem Apple-Login sofort via supabase.auth.update() persistiert (Pitfall 1)"
  - "@EnvironmentObject statt @Environment in SignInWithAppleView — iOS 16 Minimum (nicht iOS 17+ Syntax)"
  - ".task{} auf WindowGroup-Level in FamilyScoreApp.swift garantiert INITIAL_SESSION nie verpasst wird (Pitfall 2)"
  - "Phase 1 DEBUG-Funktionen (verifyAppGroup, verifySupabaseConnection) beibehalten fuer SC-3/SC-4 Backward-Compat"

metrics:
  duration: ~3min (Tasks 1+2)
  completed: 2026-05-16
  status: PARTIAL — Tasks 1+2 abgeschlossen, Task 3 wartet auf Human-Verification (echtes Geraet)
---

# Phase 2 Plan 03: Sign in with Apple + FamilyScoreApp.swift Wiring — Summary (Partial)

**SHA256-Nonce-gesicherter Sign in with Apple via ASAuthorizationController + FamilyScoreApp.swift als vollstaendiger Auth-Entry-Point mit @StateObject AuthService, .environmentObject Injection und .task{} auf WindowGroup-Level**

## Status

**PARTIAL — Tasks 1 und 2 abgeschlossen. Task 3 (Checkpoint) wartet auf manuelle Verifikation auf echtem iOS-Geraet.**

## Performance

- **Duration Tasks 1+2:** ~3 min
- **Started:** 2026-05-16T06:02:21Z
- **Tasks abgeschlossen:** 2 von 3
- **Files created:** 1
- **Files modified:** 2

## Accomplishments

### Task 1: SignInWithAppleView implementiert + LoginView integriert

- `SignInWithAppleView.swift` erstellt mit vollstaendigem Nonce-Fluss:
  - `SecRandomCopyBytes` generiert kryptographisch sicheren 32-Zeichen rawNonce
  - `request.nonce = sha256(nonce)` sendet Hash an Apple (nicht den rawNonce)
  - `signInWithIdToken(nonce: currentNonce)` sendet rawNonce an Supabase (nicht sha256)
  - STRIDE T-2-05 und T-2-06 vollstaendig mitigiert
- Apple fullName-Persistenz: `supabase.auth.update()` direkt nach erstem Login (Pitfall 1 vermieden)
- Apple-Abbruch: `ASAuthorizationError.canceled` setzt keinen `authError` (Pitfall 5 vermieden)
- `@EnvironmentObject private var authService: AuthService` (iOS 16 kompatibel, nicht iOS 17+ `@Environment`)
- `LoginView.swift` erweitert: Trennlinie "oder" + `SignInWithAppleView()` nach dem Einloggen-Button

### Task 2: FamilyScoreApp.swift als vollstaendiger Auth-Entry-Point

- `@StateObject private var authService = AuthService()` — iOS 16 ObservableObject-Muster
- `RootView()` ersetzt `ContentView()` als Wurzel-View
- `.environmentObject(authService)` injiziert AuthService in gesamte View-Hierarchy
- `.task { await authService.startObserving() }` auf WindowGroup-Level — INITIAL_SESSION wird garantiert nicht verpasst (Pitfall 2 vermieden, T-2-10 mitigiert)
- Phase 1 DEBUG-Funktionen (`verifyAppGroup`, `verifySupabaseConnection`) beibehalten unter `#if DEBUG`

## Task Commits

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | SignInWithAppleView + LoginView | `eb12dab` | SignInWithAppleView.swift (neu), LoginView.swift (modifiziert) |
| 2 | FamilyScoreApp.swift Entry Point | `70cc2ca` | FamilyScoreApp.swift (vollstaendig ersetzt) |

## Deviations from Plan

Keine — Tasks 1 und 2 exakt nach Plan ausgefuehrt.

## Requirements Status

| Req ID | Beschreibung | Status |
|--------|-------------|--------|
| AUTH-01 | E-Mail + Passwort registrieren und einloggen | PASS (Plan 02-02) |
| AUTH-02 | Sign in with Apple | PARTIAL — Code vollstaendig, manuelle Verifikation auf echtem Geraet ausstehend (Task 3) |
| AUTH-03 | Session-Persistenz nach App-Kill | PARTIAL — Keychain-Persistenz via supabase-swift automatisch; Verifikation auf echtem Geraet ausstehend |
| AUTH-04 | Ausloggen | PASS (Plan 02-02) |

**Phase 2 vollstaendig abgeschlossen:** NEIN — Task 3 Checkpoint ausstehend (AUTH-02 + AUTH-03 auf echtem Geraet)

## Build Status

REQUIRES MAC — `xcodebuild build -scheme FamilyScore` kann auf Windows nicht ausgefuehrt werden.

**Statische Verifikation (Windows):**

| Check | Ergebnis |
|-------|---------|
| `import AuthenticationServices` in SignInWithAppleView.swift | PASS |
| `import CryptoKit` in SignInWithAppleView.swift | PASS |
| `SecRandomCopyBytes` in SignInWithAppleView.swift | PASS |
| `nonce: currentNonce` in SignInWithAppleView.swift (rawNonce an Supabase) | PASS |
| `request.nonce = sha256(nonce)` in SignInWithAppleView.swift (Hash an Apple) | PASS |
| `code == .canceled` in SignInWithAppleView.swift (Cancel-Handling) | PASS |
| `supabase.auth.update` in SignInWithAppleView.swift (fullName-Persistenz) | PASS |
| `SignInWithAppleView` in LoginView.swift | PASS |
| `@Environment(` in SignInWithAppleView.swift (0 Zeilen — iOS 17-Syntax verboten) | PASS |
| `@EnvironmentObject` in SignInWithAppleView.swift | PASS |
| `@StateObject private var authService = AuthService()` in FamilyScoreApp.swift | PASS |
| `RootView()` in FamilyScoreApp.swift | PASS |
| `.environmentObject(authService)` in FamilyScoreApp.swift | PASS |
| `authService.startObserving()` in FamilyScoreApp.swift | PASS |
| `.task` in FamilyScoreApp.swift | PASS |

## Known Stubs

Keine neuen Stubs in diesem Plan. Bestehende Stubs aus Plan 02-02:
- `OnboardingPlaceholderView` (RootView.swift) — Phase 3 ersetzt mit echtem Family-Onboarding
- `AuthenticatedPlaceholderView` (RootView.swift) — Phase 4 ersetzt mit MainTabView

## Threat Surface

Keine neuen ungeplanten Netzwerk-Endpunkte oder Trust-Boundary-Kreuzungen.

Geplante Mitigierungen aus Threat-Register vollstaendig implementiert:
- T-2-05 (Apple Token Replay): SHA256-Nonce vollstaendig implementiert — MITIGIERT
- T-2-06 (Nonce-Verwechslung): rawNonce vs. sha256 explizit kommentiert + grep-verifiziert — MITIGIERT
- T-2-08 (Service-Role-Key im Client): signInWithIdToken braucht keinen Service-Role-Key — MITIGIERT
- T-2-10 (startObserving zu spaet): .task auf WindowGroup-Level — MITIGIERT

## Checkpoint — Task 3 Ausstehend

Task 3 ist ein `checkpoint:human-verify` (gate="blocking") und erfordert manuelle Verifikation auf einem echten iOS-Geraet.

Siehe Checkpoint-Nachricht fuer genaue Verifikationsschritte (AUTH-02, AUTH-03, AUTH-04).

**Resume-Signal:** "AUTH verifiziert" eingeben wenn alle 4 Requirements bestehen.

---
*Phase: 02-authentication*
*Partial completion: 2026-05-16*
