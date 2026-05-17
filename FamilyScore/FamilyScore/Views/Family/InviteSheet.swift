// FamilyScore/Views/Family/InviteSheet.swift
// Target Membership: FamilyScore (App) ONLY

import SwiftUI

struct InviteSheet: View {
    @EnvironmentObject private var familyService: FamilyService
    @Environment(\.dismiss) private var dismiss

    @State private var generatedCode: String? = nil
    @State private var isLoading: Bool = false
    @State private var selectedRole: MemberRole = .adult
    @State private var copied: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 32) {
                // Header
                HStack {
                    Text("Einladungscode")
                        .font(.headline).foregroundColor(.white)
                    Spacer()
                    Button("Fertig") { dismiss() }
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                if let code = generatedCode {
                    // Code-Anzeige
                    VStack(spacing: 16) {
                        Text(code)
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .tracking(8)

                        Text("Dieser Code ist 24 Stunden gueltig und kann nur einmal verwendet werden.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        Button {
                            UIPasteboard.general.string = code
                            copied = true
                            Task {
                                try? await Task.sleep(nanoseconds: 2_000_000_000)
                                copied = false
                            }
                        } label: {
                            Label(
                                copied ? "Kopiert!" : "Code kopieren",
                                systemImage: copied ? "checkmark" : "doc.on.doc"
                            )
                            .font(.headline)
                            .frame(maxWidth: .infinity).frame(height: 50)
                            .background(Color.white.opacity(0.15))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 24)

                        Button("Neuen Code generieren") {
                            generatedCode = nil
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                } else {
                    // Rollen-Picker + Generieren-Button
                    VStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Rolle des eingeladenen Mitglieds")
                                .font(.caption).foregroundColor(.secondary)
                            Picker("Rolle", selection: $selectedRole) {
                                ForEach(MemberRole.allCases, id: \.self) { role in
                                    Text(role.displayName).tag(role)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(.horizontal, 24)

                        Button {
                            Task { await generateCode() }
                        } label: {
                            Group {
                                if isLoading { ProgressView().tint(.black) }
                                else { Text("Code generieren").font(.headline) }
                            }
                            .frame(maxWidth: .infinity).frame(height: 50)
                            .background(Color.white)
                            .foregroundColor(.black)
                            .cornerRadius(12)
                        }
                        .disabled(isLoading)
                        .padding(.horizontal, 24)
                    }
                }

                Spacer()
            }
        }
    }

    private func generateCode() async {
        guard let familyId = familyService.currentFamily?.id else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            generatedCode = try await familyService.generateInvite(familyId: familyId, role: selectedRole)
        } catch {
            familyService.serviceError = error.localizedDescription
        }
    }
}

#Preview {
    InviteSheet()
        .environmentObject(FamilyService())
}
