// FamilyScore/Views/ActivityLog/ActivityLogSheet.swift
// Target Membership: FamilyScore (App) ONLY
// .sheet(.presentationDetents([.medium])) — iOS 16 nativ (RESEARCH.md Pattern 8)
// @ObservedObject (NICHT @EnvironmentObject) — Sheet-Scope (PATTERNS.md)
// T-4-05: Dauer-Picker 5–240 min (DoS-Schutz; Service cappt ebenfalls)

import SwiftUI

struct ActivityLogSheet: View {
    @ObservedObject var activityService: ActivityService
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategoryId: UUID? = nil
    @State private var selectedDuration: Int = 30    // Default 30 min (UI-SPEC)
    @State private var noteText: String = ""
    @State private var isLoading: Bool = false

    private var canSubmit: Bool { selectedCategoryId != nil && !isLoading }

    // Dynamische Punkte-Vorschau (T-4-03: nur Vorschau; authoritative Berechnung im Service)
    private var calculatedPoints: Int {
        let weight = activityService.categories
            .first(where: { $0.id == selectedCategoryId })?.pointWeight ?? 1.0
        return Int(Double(selectedDuration) * weight)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Kategorie-Auswahl (UI-SPEC Screen 2)
                Section("Kategorie") {
                    ForEach(activityService.categories) { category in
                        Button {
                            selectedCategoryId = category.id
                        } label: {
                            HStack {
                                Image(systemName: category.sfSymbol)
                                    .foregroundStyle(category.ringType == .duty
                                                     ? Color(UIColor.systemRed)
                                                     : Color(UIColor.systemGreen))
                                Text(category.name)
                                    .font(.system(size: 17))  // Body
                                    .foregroundStyle(Color.primary)
                                Spacer()
                                if selectedCategoryId == category.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color(UIColor.systemBlue))
                                }
                            }
                        }
                        .frame(minHeight: 44)   // iOS HIG Touch Target (touch spacing token)
                    }
                }

                // Dauer-Picker (UI-SPEC: Wheel, 5–240 min, 5-min-Schritte, Default 30 min)
                Section("Dauer") {
                    Picker("Dauer", selection: $selectedDuration) {
                        ForEach(Array(stride(from: 5, through: 240, by: 5)), id: \.self) { minutes in
                            Text("\(minutes) min").tag(minutes)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)

                    // Dynamische Punkte-Vorschau (UI-SPEC: Heading-Typo, systemBlue)
                    HStack {
                        Spacer()
                        Text("= \(calculatedPoints) Punkte")
                            .font(.system(size: 22, weight: .semibold))  // Heading
                            .foregroundStyle(Color(UIColor.systemBlue))
                    }
                }

                // Notiz-Feld (optional, UI-SPEC Screen 2)
                Section("Notiz (optional)") {
                    TextField("Kurze Beschreibung (optional)", text: $noteText)
                        .font(.system(size: 17))  // Body
                }
            }
            .navigationTitle("Aktivitaet erfassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Abbrechen — top-left TextButton (UI-SPEC Screen 2)
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(Color(UIColor.systemBlue))
                }
            }
            // Speichern-Button — full-width, 44pt, ProgressView bei isLoading (UI-SPEC)
            .safeAreaInset(edge: .bottom) {
                Button {
                    Task { await saveActivity() }
                } label: {
                    Group {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Speichern").font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)   // touch spacing token (UI-SPEC)
                    .background(canSubmit
                                ? Color(UIColor.systemBlue)
                                : Color(UIColor.systemBlue).opacity(0.3))
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                }
                .disabled(!canSubmit)
                .padding(16)
            }
        }
    }

    // MARK: - Speichern

    private func saveActivity() async {
        guard canSubmit, let categoryId = selectedCategoryId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let note = noteText.trimmingCharacters(in: .whitespaces)
            try await activityService.logActivity(
                categoryId: categoryId,
                durationMinutes: selectedDuration,
                title: note.isEmpty ? nil : note
            )
            dismiss()
        } catch {
            // Fehler bereits in activityService.activityError gesetzt (im Service)
            // DashboardView zeigt .alert fuer activityError
        }
    }
}

#Preview {
    ActivityLogSheet(activityService: ActivityService())
        .presentationDetents([.medium])
}
