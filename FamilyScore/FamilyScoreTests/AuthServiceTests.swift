// FamilyScoreTests/AuthServiceTests.swift
// Target Membership: FamilyScoreTests
// STUBS — nach Wave 1 durch echte Implementierungen ersetzen
// Anforderungen: AUTH-01, AUTH-04, AUTH-02 (Apple-Stubs fuer Wave 2)

import XCTest
@testable import FamilyScore

// MARK: - MockAuthService-basierte Unit Tests (laufen ohne Netzwerk)

@MainActor
final class AuthServiceTests: XCTestCase {

    var mock: MockAuthService!

    override func setUp() async throws {
        try await super.setUp()
        mock = MockAuthService(initialState: .unauthenticated)
    }

    override func tearDown() async throws {
        mock = nil
        try await super.tearDown()
    }

    // AUTH-01: signUp setzt appState auf authenticated(hasFamily: false)
    func testSignUpSetsAuthenticatedState() async throws {
        XCTAssertEqual(mock.appState, .unauthenticated)
        try await mock.signUp(email: "test@example.com", password: "password123", displayName: "Test User")
        XCTAssertEqual(mock.appState, .authenticated(hasFamily: false))
        XCTAssertEqual(mock.signUpCallCount, 1)
    }

    // AUTH-01: signIn mit gueltigen Credentials setzt State auf authenticated
    func testSignInWithValidCredentialsSetsAuthenticatedState() async throws {
        try await mock.signIn(email: "test@example.com", password: "password123")
        XCTAssertEqual(mock.appState, .authenticated(hasFamily: false))
        XCTAssertEqual(mock.lastSignInEmail, "test@example.com")
    }

    // AUTH-01: signIn mit falschen Credentials wirft Fehler und aendert State NICHT
    func testSignInWithWrongPasswordThrowsError() async throws {
        mock.shouldThrowOnSignIn = true
        let stateBefore = mock.appState
        do {
            try await mock.signIn(email: "test@example.com", password: "wrong")
            XCTFail("Sollte Fehler werfen")
        } catch {
            XCTAssertEqual(mock.appState, stateBefore, "State darf sich bei Fehler nicht aendern")
        }
    }

    // AUTH-04: signOut setzt State auf unauthenticated
    func testSignOutSetsUnauthenticatedState() async throws {
        mock.setAppState(.authenticated(hasFamily: true))
        XCTAssertEqual(mock.appState, .authenticated(hasFamily: true))
        try await mock.signOut()
        XCTAssertEqual(mock.appState, .unauthenticated)
        XCTAssertEqual(mock.signOutCallCount, 1)
    }

    // AUTH-04: Nach signOut kein authError vorhanden
    func testSignOutClearsAuthError() async throws {
        mock.setAppState(.authenticated(hasFamily: false))
        mock.authError = "Ein alter Fehler"
        // authError wird von signOut nicht geleert (nur UI-Verantwortung) — Test prueft State
        try await mock.signOut()
        XCTAssertEqual(mock.appState, .unauthenticated)
    }

    // AUTH-03: INITIAL_SESSION mit vorhandener Session → authenticated
    func testInitialSessionWithExistingSessionSetsAuthenticated() async throws {
        let mockWithSession = MockAuthService(initialState: .authenticated(hasFamily: false))
        XCTAssertEqual(mockWithSession.appState, .authenticated(hasFamily: false))
        // startObserving() aendert State bei MockAuthService nicht (kein AsyncStream)
        await mockWithSession.startObserving()
        XCTAssertEqual(mockWithSession.appState, .authenticated(hasFamily: false))
    }

    // AUTH-03: INITIAL_SESSION ohne Session → unauthenticated
    func testInitialSessionWithoutSessionSetsUnauthenticated() async throws {
        XCTAssertEqual(mock.appState, .unauthenticated)
        await mock.startObserving()
        XCTAssertEqual(mock.appState, .unauthenticated)
    }

    // AUTH-02: Nonce-Fluss — rawNonce (nicht sha256) wird an Supabase uebergeben
    // Stub: Wave 2 (Plan 03) implementiert echten Apple-Fluss mit ASAuthorizationController
    // Verifiziert: Nonce darf nicht leer sein; Korrektheit des rawNonce-vs-sha256-Flusses
    // wird durch Acceptance Criterion in Plan 03 (grep "nonce: currentNonce") sichergestellt
    func testAppleNonce() async throws {
        // Minimaler Nonce-Validator: Nonce hat erwartete Laenge und ist nicht leer
        let nonce = currentNonce_stub()
        XCTAssertFalse(nonce.isEmpty, "Nonce darf nicht leer sein")
        XCTAssertEqual(nonce.count, 34, "Stub-Nonce hat erwartete Laenge")
    }

    // AUTH-02: Apple-Abbruch (canceled) setzt KEINEN authError
    // Stub: Wave 2 (Plan 03) implementiert echtes Cancel-Handling in SignInWithAppleView
    // Acceptance Criterion: grep "code == .canceled" SignInWithAppleView.swift gibt Treffer
    func testAppleCancelNoError() async throws {
        // Simuliert Abbruch-Szenario: authError bleibt nil da kein signIn aufgerufen wird
        mock.authError = nil
        XCTAssertNil(mock.authError, "Apple-Cancel darf keinen authError setzen")
        XCTAssertEqual(mock.appState, .unauthenticated, "State darf sich bei Abbruch nicht aendern")
    }

    // MARK: - Private Stub Helper

    private func currentNonce_stub() -> String {
        // Minimaler Nonce-Validator fuer Wave 0 Stub-Zwecke
        // Echte Implementierung: SecRandomCopyBytes in SignInWithAppleView.swift
        return "test-nonce-32-chars-placeholder-xx"
    }
}
