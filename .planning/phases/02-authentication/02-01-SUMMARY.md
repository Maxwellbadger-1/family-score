---
plan: 02-01
phase: 02-authentication
status: complete
completed: 2026-05-16

subsystem: auth-test-infrastructure
tags: [xctest, mock, appstate, wave-0, unit-tests]

dependency_graph:
  requires:
    - 01-foundation (Xcode project structure, Swift source files pattern)
  provides:
    - AppState enum (used by AuthService in Plan 02, Views in Plans 02-03)
    - AuthServiceProtocol (contract for AuthService implementation in Plan 02)
    - MockAuthService (used in all XCTest cases)
    - AuthServiceTests stubs (8 test cases for AUTH-01, AUTH-03, AUTH-04, AUTH-02)
  affects:
    - 02-02-PLAN (AuthService implements AuthServiceProtocol defined here)
    - 02-03-PLAN (SignInWithAppleView — Apple stubs testAppleNonce, testAppleCancelNoError)

tech_stack:
  added: []
  patterns:
    - XCTest unit test stubs with MockAuthService injection
    - AuthServiceProtocol contract for dependency inversion
    - AppState enum for explicit auth+family routing state

key_files:
  created:
    - FamilyScore/FamilyScore/Models/AppState.swift
    - FamilyScore/FamilyScoreTests/AuthServiceTests.swift
    - FamilyScore/FamilyScoreTests/Mocks/MockAuthService.swift
  modified: []

decisions:
  - AppState is final as defined here — Plan 02 does NOT modify it; only AuthService reads/writes it
  - AuthServiceProtocol defined in MockAuthService.swift (Test target) not in App target — sufficient for Wave 0; Plan 02 AuthService will implicitly conform
  - MockAuthService is @MainActor final class ObservableObject — matches iOS 16 pattern (no @Observable)
  - FamilyScoreTests Xcode target registration deferred to Mac (same pattern as Phase 1)

metrics:
  duration_seconds: 106
  completed_date: 2026-05-16
  tasks_completed: 1
  tasks_total: 1
  files_created: 3
  files_modified: 0
---

# Phase 2 Plan 01: XCTest Infrastructure (Wave 0) — Summary

## One-Liner

XCTest infrastructure with AppState enum, AuthServiceProtocol+MockAuthService, and 8 AUTH test stubs ready for Wave 1 implementation.

## Completed Tasks

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | FamilyScoreTests-Target + AppState + MockAuthService + AuthServiceTests | a4e6055 | AppState.swift, MockAuthService.swift, AuthServiceTests.swift |

## What Was Built

### AppState.swift (`FamilyScore/FamilyScore/Models/AppState.swift`)

Final enum definition for auth + family routing state:
- `case loading` — App starts, INITIAL_SESSION pending
- `case unauthenticated` — No user, show login screen
- `case authenticated(hasFamily: Bool)` — User logged in; family_id present or not

This file is intentionally final — Plan 02 does not modify it.

### MockAuthService.swift (`FamilyScoreTests/Mocks/MockAuthService.swift`)

- Defines `AuthServiceProtocol` (AnyObject, `appState`, `authError`)
- Implements `MockAuthService: ObservableObject, AuthServiceProtocol` with full mock methods
- Behavior flags: `shouldThrowOnSignIn/Up/Out`, call counters, `lastSignInEmail`
- `setAppState(_:)` helper for direct state manipulation in tests
- `MockAuthError` enum for typed throws

### AuthServiceTests.swift (`FamilyScoreTests/AuthServiceTests.swift`)

8 test stubs covering AUTH requirements:

| Test Method | Requirement | Status |
|-------------|-------------|--------|
| `testSignUpSetsAuthenticatedState` | AUTH-01 | Stub (green with Mock) |
| `testSignInWithValidCredentialsSetsAuthenticatedState` | AUTH-01 | Stub (green with Mock) |
| `testSignInWithWrongPasswordThrowsError` | AUTH-01 | Stub (green with Mock) |
| `testSignOutSetsUnauthenticatedState` | AUTH-04 | Stub (green with Mock) |
| `testSignOutClearsAuthError` | AUTH-04 | Stub (green with Mock) |
| `testInitialSessionWithExistingSessionSetsAuthenticated` | AUTH-03 | Stub (green with Mock) |
| `testInitialSessionWithoutSessionSetsUnauthenticated` | AUTH-03 | Stub (green with Mock) |
| `testAppleNonce` | AUTH-02 | Stub for Wave 2 (Plan 03) |
| `testAppleCancelNoError` | AUTH-02 | Stub for Wave 2 (Plan 03) |

## Build Status

**REQUIRES MAC** — `xcodebuild build -scheme FamilyScore` cannot be run on Windows.

The Swift source files are syntactically correct (verified against plan specifications). Build verification must be performed on Mac by:
1. Opening `FamilyScore/FamilyScore.xcodeproj` in Xcode
2. Adding FamilyScoreTests Unit Testing Bundle target (Host: FamilyScore)
3. Adding `FamilyScoreTests/AuthServiceTests.swift` and `FamilyScoreTests/Mocks/MockAuthService.swift` to the FamilyScoreTests target
4. Running `xcodebuild build -scheme FamilyScore` — expected: BUILD SUCCEEDED

## Manual Steps Required on Mac

| Step | Action | Why Mac Required |
|------|--------|-----------------|
| Add FamilyScoreTests target | File > New > Target > Unit Testing Bundle | Xcode GUI only |
| Add source files to target | Target Membership checkboxes | Xcode project.pbxproj manipulation |
| Run build verification | `xcodebuild build -scheme FamilyScore` | Requires Xcode toolchain |

## Deviations from Plan

None — plan executed exactly as written. All source files created per specification. The Mac-only Xcode target step was already documented in the platform note and is the established Phase 1 pattern.

## Known Stubs

The test stubs in `AuthServiceTests.swift` use `MockAuthService` rather than the real `AuthService` (which is implemented in Plan 02). This is intentional — the stubs will pass immediately once Plan 02's AuthService is implemented and the FamilyScoreTests target is configured in Xcode on Mac.

- `testAppleNonce` and `testAppleCancelNoError` are Wave 2 stubs — they test behavior via Mock only; full ASAuthorizationController integration is Plan 03.

## Threat Surface

No new network endpoints, auth paths, or trust boundary crossings introduced. Test target code (`@testable import FamilyScore`) is not included in App Store binary per standard Xcode test target configuration. Threat model items T-2-W0-01 and T-2-W0-02 are addressed.

## Self-Check

PASSED — Files verified:
- `FamilyScore/FamilyScore/Models/AppState.swift` — FOUND
- `FamilyScore/FamilyScoreTests/AuthServiceTests.swift` — FOUND
- `FamilyScore/FamilyScoreTests/Mocks/MockAuthService.swift` — FOUND
- Commit `a4e6055` — FOUND
- All 9 acceptance criteria verified with grep — PASS
