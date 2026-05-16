---
phase: 02-authentication
plan: "02"
subsystem: auth
tags: [supabase, swiftui, authservice, observableobject, ios16, keychain, environmentobject]

dependency_graph:
  requires:
    - phase: 02-01
      provides: AppState enum, AuthServiceProtocol, MockAuthService, AuthServiceTests stubs
    - phase: 01-foundation
      provides: Supabase.swift global client, FamilyScore Xcode project structure
  provides:
    - AuthService (ObservableObject, authStateChanges loop, signUp/signIn/signOut)
    - Supabase.swift with KeychainLocalStorage(service:com.familyscore)
    - RootView with AppState-based routing (4 cases)
    - AuthFlowView (segmented Login/Register tab container)
    - LoginView (email+password, validation, error banner)
    - RegisterView (name+email+password+confirm, password match validation)
  affects:
    - 02-03-PLAN (SignInWithAppleView uses same AuthService and authService.authError pattern)
    - 03-family-core (FamilyScoreApp.swift wires authService.startObserving() — Plan 02-03 Task 2)

tech-stack:
  added: []
  patterns:
    - ObservableObject + @Published (iOS 16 compatible — NOT @Observable which is iOS 17+)
    - authStateChanges AsyncStream loop as single source of auth truth
    - @EnvironmentObject injection for AuthService in all Views
    - AppState-switch routing in RootView (no if/else boolean soup)
    - Placeholder views for future phases (OnboardingPlaceholder, AuthenticatedPlaceholder)
    - localizedError(from:) pattern — raw server errors never reach UI

key-files:
  created:
    - FamilyScore/FamilyScore/Services/AuthService.swift
    - FamilyScore/FamilyScore/Views/RootView.swift
    - FamilyScore/FamilyScore/Views/Auth/AuthFlowView.swift
    - FamilyScore/FamilyScore/Views/Auth/LoginView.swift
    - FamilyScore/FamilyScore/Views/Auth/RegisterView.swift
  modified:
    - FamilyScore/FamilyScore/Supabase.swift (added KeychainLocalStorage options)

key-decisions:
  - "AuthService.startObserving() is NOT called in RootView — only FamilyScoreApp.swift (Plan 02-03) starts the loop to prevent race conditions"
  - "ObservableObject + @Published used throughout (NOT @Observable) — iOS 16.0 minimum enforced"
  - "checkFamilyMembership() is private and async — called only inside authStateChanges loop after SIGNED_IN"
  - "KeychainLocalStorage(service: com.familyscore) prevents macOS/iOS Keychain prompt bug (Discussion #28132)"
  - "OnboardingPlaceholderView and AuthenticatedPlaceholderView are intentional stubs — replaced in Phase 3 and 4"

requirements-completed: [AUTH-01, AUTH-03, AUTH-04]

duration: 20min
completed: 2026-05-16
---

# Phase 2 Plan 02: Auth Service + Views — Summary

**ObservableObject AuthService with authStateChanges loop (initialSession/signedIn/signedOut) plus RootView/AuthFlowView/LoginView/RegisterView with iOS 16-compatible @EnvironmentObject wiring**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-05-16T05:51:34Z
- **Completed:** 2026-05-16T07:57:00Z
- **Tasks:** 2
- **Files created:** 5
- **Files modified:** 1

## Accomplishments

- AuthService implements ObservableObject with full authStateChanges AsyncStream loop covering INITIAL_SESSION, SIGNED_IN, SIGNED_OUT and TOKEN_REFRESHED — no manual token management
- Supabase.swift updated with KeychainLocalStorage(service: "com.familyscore") to prevent Keychain prompt bug on macOS/iOS Simulator
- RootView routes to all 4 AppState cases (.loading, .unauthenticated, .authenticated(hasFamily: false/true)) without calling startObserving() (Race Condition prevention)
- LoginView and RegisterView implement full form validation (canSubmit guard, password length, password match), error banner with dismiss button, loading state, and keyboard focus chain
- All views use @EnvironmentObject (iOS 16 compatible) — zero uses of @Environment for ObservableObject

## Task Commits

1. **Task 1: AuthService + Supabase.swift** — `c69248b` (feat — pre-committed in prior session as part of docs(04) commit)
2. **Task 2: RootView + AuthFlowView + LoginView + RegisterView** — `ea7b247` (feat)

## Files Created/Modified

- `FamilyScore/FamilyScore/Services/AuthService.swift` — ObservableObject with authStateChanges loop, signUp/signIn/signOut, checkFamilyMembership, localizedError
- `FamilyScore/FamilyScore/Supabase.swift` — Added KeychainLocalStorage(service: "com.familyscore") to prevent Keychain prompt bug
- `FamilyScore/FamilyScore/Views/RootView.swift` — AppState-based routing with 4 cases, OnboardingPlaceholderView, AuthenticatedPlaceholderView
- `FamilyScore/FamilyScore/Views/Auth/AuthFlowView.swift` — Segmented Picker container switching between LoginView and RegisterView
- `FamilyScore/FamilyScore/Views/Auth/LoginView.swift` — Email+password fields, canSubmit validation, error banner, loading spinner
- `FamilyScore/FamilyScore/Views/Auth/RegisterView.swift` — Name+email+password+confirm fields, password match validation with red highlight

## Decisions Made

- `startObserving()` is intentionally absent from RootView — wired only in FamilyScoreApp.swift (Plan 02-03 Task 2) to prevent two concurrent AsyncStream loops causing race conditions on appState
- `checkFamilyMembership()` uses `UUID?` for `family_id` (not `String?`) per the plan spec — more type-safe than the RESEARCH.md Pattern 2 example which used `String?`
- Placeholder views (`OnboardingPlaceholderView`, `AuthenticatedPlaceholderView`) include an "Ausloggen" button so testers can exercise the signOut flow before Phase 3/4 are complete

## Deviations from Plan

### Pre-existing commit (not a bug, context deviation)

**[Context] Task 1 files already committed in prior session**
- **Found during:** Task 1 git staging
- **Issue:** `AuthService.swift` and the updated `Supabase.swift` were already committed in commit `c69248b` (titled "docs(04): UI design contract") from a previous session. Content was identical to what the plan specified.
- **Fix:** No re-implementation needed — files were verified against plan acceptance criteria and passed all checks. Task 2 proceeded normally.
- **Impact:** Task 1 has no separate `feat(02-02)` commit; it is part of `c69248b`. All acceptance criteria still met.

---

**Total deviations:** 1 (context — prior session pre-committed Task 1 files)
**Impact on plan:** No functional impact. All acceptance criteria verified and passed.

## Known Stubs

| Stub | File | Line | Reason |
|------|------|------|--------|
| `OnboardingPlaceholderView` | RootView.swift | 40 | Intentional — Phase 3 replaces with real family onboarding flow |
| `AuthenticatedPlaceholderView` | RootView.swift | 68 | Intentional — Phase 4 replaces with MainTabView (Dashboard) |

These stubs do NOT block plan goals: AUTH-01/03/04 are fully implemented via AuthService. The placeholder views correctly display after successful login and allow testing signOut. Phase 3 and 4 will replace them with real UI.

## Issues Encountered

None — plan executed per specification. `git status` did not show new Swift files as untracked due to them already being in the git index from a prior session. Diagnosed via `git ls-files --cached` and `git log`.

## Build Status

REQUIRES MAC — `xcodebuild build -scheme FamilyScore` cannot be executed on Windows.

**Static verification completed on Windows:**
- All acceptance criteria grep checks: PASS
- `@Observable` as code annotation: 0 occurrences (iOS 16 constraint honored)
- `@Published` count in AuthService: 3 real properties (appState, currentUser, authError)
- `startObserving()` in RootView: 0 actual calls (only in comments)
- `@EnvironmentObject` in all views: confirmed
- No hardcoded Supabase URLs in Services/ or Views/: confirmed

**Build verification on Mac:**
1. Open `FamilyScore/FamilyScore.xcodeproj`
2. Add `FamilyScore/FamilyScore/Services/AuthService.swift` to FamilyScore target membership
3. Add `FamilyScore/FamilyScore/Views/` files to FamilyScore target membership
4. Run `xcodebuild build -scheme FamilyScore` — expected: BUILD SUCCEEDED

## Next Phase Readiness

- **Plan 02-03** (Wave 2): Sign in with Apple — can use AuthService directly; SignInWithAppleView receives `@EnvironmentObject var authService: AuthService` same as LoginView
- **Plan 02-03 Task 2**: `FamilyScoreApp.swift` must call `authService.startObserving()` via `.task {}` — this is the final wire that activates the authStateChanges loop
- **Phase 3**: `OnboardingPlaceholderView` → real `CreateFamilyView`/`JoinFamilyView`; `AuthenticatedPlaceholderView` → `MainTabView`

## Threat Surface

No new unplanned network endpoints or trust boundary crossings. All auth flows go through `supabase.auth.*` (planned). The `localizedError(from:)` pattern ensures raw server error messages never reach the UI (T-2-07 mitigation active).

---
*Phase: 02-authentication*
*Completed: 2026-05-16*
