// FamilyScore/Views/RootView.swift
// Target Membership: FamilyScore (App) ONLY
// iOS 16: @EnvironmentObject statt @Environment fuer ObservableObject
// KEIN .task { await authService.startObserving() } hier —
//   startObserving() wird in FamilyScoreApp.swift gestartet (Plan 03 Task 2)
//   Zwei simultane startObserving()-Schleifen wuerden Race Condition auf appState erzeugen.

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authService: AuthService

    var body: some View {
        Group {
            switch authService.appState {
            case .loading:
                // Splash waehrend INITIAL_SESSION-Event aussteht
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)

            case .unauthenticated:
                AuthFlowView()

            case .authenticated(hasFamily: false):
                // Phase 3 liefert echten Onboarding-Flow (Familiengruppe erstellen/beitreten)
                OnboardingPlaceholderView()

            case .authenticated(hasFamily: true):
                // Phase 4 liefert MainTabView (Dashboard, Aktivitaeten, Einstellungen)
                AuthenticatedPlaceholderView()
            }
        }
    }
}

// MARK: - Placeholder Views (werden in spaeteren Phasen ersetzt)

struct OnboardingPlaceholderView: View {
    @EnvironmentObject private var authService: AuthService

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.white)
                Text("Willkommen!")
                    .font(.title.bold())
                    .foregroundColor(.white)
                Text("Familiengruppe einrichten kommt bald (Phase 3).")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button("Ausloggen") {
                    Task { try? await authService.signOut() }
                }
                .foregroundColor(.red)
                .padding(.top, 32)
            }
        }
    }
}

struct AuthenticatedPlaceholderView: View {
    @EnvironmentObject private var authService: AuthService

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                Text("Eingeloggt!")
                    .font(.title.bold())
                    .foregroundColor(.white)
                Text("Dashboard kommt in Phase 4.")
                    .font(.body)
                    .foregroundColor(.secondary)
                Button("Ausloggen") {
                    Task { try? await authService.signOut() }
                }
                .foregroundColor(.red)
                .padding(.top, 32)
            }
        }
    }
}

#Preview {
    // AuthService ist final — kein Subclassing moeglich.
    // Direkte Instanz zeigt .loading-State (Default) als Preview.
    RootView()
        .environmentObject(AuthService())
}
