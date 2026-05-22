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
        ZStack(alignment: .bottom) {
            Group {
                switch authService.appState {
                case .loading:
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)

                case .unauthenticated:
                    AuthFlowView()

                case .authenticated(hasFamily: false):
                    // Phase 3: Echter Onboarding-Flow (Familie erstellen oder beitreten)
                    FamilyOnboardingView()

                case .authenticated(hasFamily: true):
                    // Phase 4: DashboardView als Haupt-Screen
                    DashboardView()
                }
            }

            #if DEBUG
            DebugStateOverlay(appState: authService.appState, error: authService.authError)
            #endif
        }
    }
}

// MARK: - Debug Overlay (DEBUG-Builds only, in Appetize sichtbar)

#if DEBUG
struct DebugStateOverlay: View {
    let appState: AppState
    let error: String?

    private var stateLabel: String {
        switch appState {
        case .loading:                     return "State: loading"
        case .unauthenticated:             return "State: unauthenticated"
        case .authenticated(hasFamily: false): return "State: authenticated (no family)"
        case .authenticated(hasFamily: true):  return "State: authenticated (has family)"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(stateLabel)
            if let error {
                Text("Error: \(error)")
                    .foregroundColor(.red)
            }
        }
        .font(.system(size: 11, design: .monospaced))
        .foregroundColor(.yellow)
        .padding(6)
        .background(Color.black.opacity(0.7))
        .cornerRadius(6)
        .padding(.bottom, 12)
        .padding(.horizontal, 12)
        .allowsHitTesting(false)
    }
}
#endif

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
    @EnvironmentObject private var familyService: FamilyService

    var body: some View {
        NavigationStack {
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
                    NavigationLink(destination: MemberListView()) {
                        Text("Familie verwalten")
                    }
                    .padding(.top, 16)
                    Button("Ausloggen") {
                        Task { try? await authService.signOut() }
                    }
                    .foregroundColor(.red)
                    .padding(.top, 32)
                }
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AuthService())
}
