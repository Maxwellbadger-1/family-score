// FamilyScore/Views/Family/CreateFamilyView.swift
// Target Membership: FamilyScore (App) ONLY
// Analog: RegisterView.swift (Phase 2) -- ein Eingabefeld + Submit-Muster

import SwiftUI
@preconcurrency import Supabase

struct CreateFamilyView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var familyService: FamilyService
    @Environment(\.dismiss) private var dismiss

    @State private var familyName: String = ""
    @State private var isLoading: Bool = false
    @FocusState private var isFocused: Bool

    private var canSubmit: Bool {
        !familyName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                        .padding(.top, 40)
                    Text("Neue Familie")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }

                // Fehler-Banner
                if let error = familyService.serviceError {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill").foregroundColor(.red)
                        Text(error).font(.subheadline).foregroundColor(.red)
                        Spacer()
                        Button { familyService.serviceError = nil } label: {
                            Image(systemName: "xmark").foregroundColor(.secondary)
                        }
                    }
                    .padding(12)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal, 24)
                }

                // Familienname-Feld
                VStack(alignment: .leading, spacing: 4) {
                    Text("Familienname")
                        .font(.caption).foregroundColor(.secondary)
                    TextField("", text: $familyName)
                        .focused($isFocused)
                        .submitLabel(.done)
                        .onSubmit { if canSubmit { Task { await submit() } } }
                        .padding(12)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 24)

                // Erstellen-Button
                Button {
                    Task { await submit() }
                } label: {
                    Group {
                        if isLoading { ProgressView().tint(.black) }
                        else { Text("Familie erstellen").font(.headline) }
                    }
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(canSubmit ? Color.white : Color.white.opacity(0.3))
                    .foregroundColor(.black)
                    .cornerRadius(12)
                }
                .disabled(!canSubmit || isLoading)
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { isFocused = true }
    }

    private func submit() async {
        guard canSubmit else { return }
        isLoading = true
        defer { isLoading = false }

        // DEBUG: Session-Info sammeln und anzeigen
        var dbg = "[DEBUG]\n"
        do {
            let sess = try await supabase.auth.session
            let exp = sess.expiresAt
            let remaining = Int(exp.timeIntervalSinceNow)
            dbg += "uid: \(sess.user.id)\n"
            dbg += "email: \(sess.user.email ?? "nil")\n"
            dbg += "token: \(String(sess.accessToken.prefix(30)))\n"
            dbg += "exp in: \(remaining)s\n"
            dbg += "expired: \(exp < Date())\n"
        } catch {
            dbg += "session() FEHLER: \(error)\n"
        }
        do {
            let r = try await supabase.auth.refreshSession()
            dbg += "refresh: OK uid=\(r.user.id)\n"
        } catch {
            dbg += "refresh: FEHLER \(error)\n"
        }
        familyService.serviceError = dbg
        // 5s Pause damit der Text lesbar ist
        try? await Task.sleep(nanoseconds: 5_000_000_000)

        do {
            _ = try await familyService.createFamily(
                name: familyName.trimmingCharacters(in: .whitespaces)
            )
            await authService.refreshFamilyStatus()
        } catch {
            familyService.serviceError = dbg + "\nRPC: \(error)"
        }
    }
}

#Preview {
    NavigationStack {
        CreateFamilyView()
            .environmentObject(AuthService())
            .environmentObject(FamilyService())
    }
}
