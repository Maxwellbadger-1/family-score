// FamilyScore/Views/Family/JoinFamilyView.swift
// Target Membership: FamilyScore (App) ONLY
// Analog: LoginView.swift (Phase 2) -- ein Eingabefeld + Submit

import SwiftUI

struct JoinFamilyView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var familyService: FamilyService
    @Environment(\.dismiss) private var dismiss

    @State private var inviteCode: String = ""
    @State private var isLoading: Bool = false
    @FocusState private var isFocused: Bool

    private var canSubmit: Bool { inviteCode.count == 8 }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                        .padding(.top, 40)
                    Text("Familie beitreten")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("Gib den 8-stelligen Code ein, den dir ein Familien-Admin gegeben hat.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
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

                // Code-Eingabefeld
                VStack(alignment: .leading, spacing: 4) {
                    Text("Einladungscode (8 Zeichen)")
                        .font(.caption).foregroundColor(.secondary)
                    TextField("", text: $inviteCode)
                        .keyboardType(.asciiCapable)
                        .autocapitalization(.allCharacters)
                        .autocorrectionDisabled()
                        .focused($isFocused)
                        .submitLabel(.go)
                        .onSubmit { if canSubmit { Task { await submit() } } }
                        .onChange(of: inviteCode) { new in
                            if new.count > 8 { inviteCode = String(new.prefix(8)) }
                            inviteCode = inviteCode.uppercased()
                        }
                        .font(.system(.title2, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .padding(12)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                    // Zeichenzaehler
                    Text("\(inviteCode.count)/8")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 24)

                // Beitreten-Button
                Button {
                    Task { await submit() }
                } label: {
                    Group {
                        if isLoading { ProgressView().tint(.black) }
                        else { Text("Beitreten").font(.headline) }
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
        do {
            _ = try await familyService.joinFamily(token: inviteCode)
            await authService.refreshFamilyStatus()
        } catch {
            familyService.serviceError = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        JoinFamilyView()
            .environmentObject(AuthService())
            .environmentObject(FamilyService())
    }
}
