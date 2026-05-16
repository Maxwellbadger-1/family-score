// FamilyScore/Views/Auth/AuthFlowView.swift
// Target Membership: FamilyScore (App) ONLY
// TabView-Container fuer Login und Registrierung
// Apple Health Aesthetik: dunkler Hintergrund, Segment-Picker, klare Struktur

import SwiftUI

struct AuthFlowView: View {
    @State private var selectedTab: AuthTab = .login

    enum AuthTab {
        case login, register
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "figure.2.and.child.holdinghands")
                        .font(.system(size: 52))
                        .foregroundColor(.white)
                        .padding(.top, 60)
                    Text("Family Score")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    Text("Gemeinsam mehr erreichen")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 32)

                // Tab-Switcher
                Picker("", selection: $selectedTab) {
                    Text("Einloggen").tag(AuthTab.login)
                    Text("Registrieren").tag(AuthTab.register)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

                // Content
                Group {
                    switch selectedTab {
                    case .login:
                        LoginView()
                    case .register:
                        RegisterView()
                    }
                }

                Spacer()
            }
        }
    }
}

#Preview {
    AuthFlowView()
        .environmentObject(AuthService())
}
