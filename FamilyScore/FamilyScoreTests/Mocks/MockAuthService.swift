// FamilyScoreTests/Mocks/MockAuthService.swift
// Target Membership: FamilyScoreTests ONLY
// Zweck: Unit-Tests und SwiftUI-Previews (via .environment)

import Foundation
import Combine
@testable import FamilyScore

// Protocol definiert den Vertrag — AuthService (Wave 1) muss diesen erfullen
// MockAuthService implementiert ihn fuer Tests

protocol AuthServiceProtocol: AnyObject {
    var appState: AppState { get }
    var authError: String? { get set }
}

@MainActor
final class MockAuthService: ObservableObject, AuthServiceProtocol {
    @Published private(set) var appState: AppState
    @Published var authError: String? = nil

    // Verhalten-Flags fuer Unit-Tests
    var shouldThrowOnSignIn: Bool = false
    var shouldThrowOnSignUp: Bool = false
    var shouldThrowOnSignOut: Bool = false
    var signInCallCount: Int = 0
    var signUpCallCount: Int = 0
    var signOutCallCount: Int = 0
    var lastSignInEmail: String? = nil

    init(initialState: AppState = .unauthenticated) {
        self.appState = initialState
    }

    // Testhelfer: State direkt setzen
    func setAppState(_ state: AppState) {
        appState = state
    }

    func startObserving() async {
        // Mock: sofort initialState setzen, kein AsyncStream
    }

    func signUp(email: String, password: String, displayName: String) async throws {
        signUpCallCount += 1
        if shouldThrowOnSignUp {
            throw MockAuthError.signUpFailed
        }
        appState = .authenticated(hasFamily: false)
    }

    func signIn(email: String, password: String) async throws {
        signInCallCount += 1
        lastSignInEmail = email
        if shouldThrowOnSignIn {
            throw MockAuthError.invalidCredentials
        }
        appState = .authenticated(hasFamily: false)
    }

    func signOut() async throws {
        signOutCallCount += 1
        if shouldThrowOnSignOut {
            throw MockAuthError.signOutFailed
        }
        appState = .unauthenticated
    }
}

enum MockAuthError: Error {
    case signUpFailed
    case invalidCredentials
    case signOutFailed
}
