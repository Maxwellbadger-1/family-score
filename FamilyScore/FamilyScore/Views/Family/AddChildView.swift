// FamilyScore/Views/Family/AddChildView.swift
// Target Membership: FamilyScore (App) ONLY
// Analog: RegisterView.swift (zwei Felder + Submit) -- vereinfacht auf Name + Farbe

import SwiftUI

struct AddChildView: View {
    @EnvironmentObject private var familyService: FamilyService
    @Environment(\.dismiss) private var dismiss

    @State private var childName: String = ""
    @State private var selectedColor: String = "#FF9500"  // iOS Orange als Kind-Default
    @State private var isLoading: Bool = false
    @FocusState private var isFocused: Bool

    // Preset-Farben fuer Avatar (Apple Health Aesthetik: gesaettigte Systemfarben)
    private let presetColors: [(String, Color)] = [
        ("#FF3B30", .red), ("#FF9500", .orange), ("#FFCC00", .yellow),
        ("#34C759", .green), ("#007AFF", .blue), ("#AF52DE", .purple)
    ]

    private var canSubmit: Bool {
        !childName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                // Header
                HStack {
                    Button("Abbrechen") { dismiss() }
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Kind-Profil")
                        .font(.headline).foregroundColor(.white)
                    Spacer()
                    Color.clear.frame(width: 70) // Platzhalter fuer Symmetrie
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                // Avatar-Vorschau
                Circle()
                    .fill(Color(hex: selectedColor) ?? .orange)
                    .frame(width: 80, height: 80)
                    .overlay {
                        Image(systemName: "figure.child")
                            .font(.title).foregroundColor(.white)
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

                // Name-Feld
                VStack(alignment: .leading, spacing: 4) {
                    Text("Name des Kindes")
                        .font(.caption).foregroundColor(.secondary)
                    TextField("", text: $childName)
                        .textContentType(.name)
                        .focused($isFocused)
                        .submitLabel(.done)
                        .onSubmit { if canSubmit { Task { await submit() } } }
                        .padding(12)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 24)

                // Avatar-Farbe
                VStack(alignment: .leading, spacing: 8) {
                    Text("Avatar-Farbe")
                        .font(.caption).foregroundColor(.secondary)
                    HStack(spacing: 12) {
                        ForEach(presetColors, id: \.0) { hex, color in
                            Circle()
                                .fill(color)
                                .frame(width: 40, height: 40)
                                .overlay {
                                    if selectedColor == hex {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                    }
                                }
                                .onTapGesture { selectedColor = hex }
                        }
                    }
                }
                .padding(.horizontal, 24)

                // Erstellen-Button
                Button {
                    Task { await submit() }
                } label: {
                    Group {
                        if isLoading { ProgressView().tint(.black) }
                        else { Text("Profil erstellen").font(.headline) }
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
        .onAppear { isFocused = true }
    }

    private func submit() async {
        guard canSubmit else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await familyService.createChildProfile(
                name: childName.trimmingCharacters(in: .whitespaces),
                avatarColor: selectedColor
            )
            dismiss()
        } catch {
            familyService.serviceError = error.localizedDescription
        }
    }
}

#Preview {
    AddChildView()
        .environmentObject(FamilyService())
}
