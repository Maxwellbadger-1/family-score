// FamilyScore/Views/Family/FamilyOnboardingView.swift
// Target Membership: FamilyScore (App) ONLY
// iOS 16: @EnvironmentObject (NICHT @Environment fuer ObservableObject)
// Analog: AuthFlowView.swift (Phase 2)

import SwiftUI

struct FamilyOnboardingView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var familyService: FamilyService

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 52))
                            .foregroundColor(.white)
                            .padding(.top, 60)
                        Text("Familiengruppe")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        Text("Erstelle eine neue Familie oder tritt einer bestehenden bei.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    // Aktions-Buttons
                    VStack(spacing: 16) {
                        NavigationLink(destination: CreateFamilyView()) {
                            Label("Neue Familie erstellen", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(Color.white)
                                .foregroundColor(.black)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 24)

                        NavigationLink(destination: JoinFamilyView()) {
                            Label("Mit Code beitreten", systemImage: "qrcode.viewfinder")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(Color.white.opacity(0.15))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 24)
                    }

                    Spacer()

                    Button("Ausloggen") {
                        Task { try? await authService.signOut() }
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    FamilyOnboardingView()
        .environmentObject(AuthService())
        .environmentObject(FamilyService())
}
