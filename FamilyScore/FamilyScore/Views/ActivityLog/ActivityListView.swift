// FamilyScore/Views/ActivityLog/ActivityListView.swift
// Target Membership: FamilyScore (App) ONLY
// Pitfall 5 aus RESEARCH.md: .swipeActions (NICHT .onDelete) fuer korrekte confirmationDialog-Integration
// DASH-05: todayEntries ist family-weiter Feed (kein user_id-Filter hier — ActivityService liefert das)
// DASH-04: 'Alle Zeit'-Section mit allTimeStats oben in der Liste

import SwiftUI

struct ActivityListView: View {
    @EnvironmentObject private var activityService: ActivityService

    @State private var entryToDelete: ActivityEntry? = nil
    @State private var showDeleteConfirmation: Bool = false

    var body: some View {
        NavigationStack {
            List {
                // DASH-04: "Alle Zeit"-Section oben in der Liste
                Section("Gesamt (alle Zeit)") {
                    if let stats = activityService.allTimeStats {
                        HStack {
                            Label {
                                Text(String(format: "%.1f Stunden", stats.totalHours))
                                    .font(.system(size: 17))
                            } icon: {
                                Image(systemName: "clock.fill")
                                    .foregroundStyle(Color(UIColor.systemBlue))
                            }
                            Spacer()
                            Text(String(format: "%.0f Punkte", stats.totalPoints))
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color(UIColor.systemBlue))
                        }
                    } else {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Lade Statistiken...")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // DASH-05: family-weiter Tages-Feed (groupedByDay aus todayEntries — alle Familienmitglieder)
                if activityService.todayEntries.isEmpty {
                    Section {
                        // Leerstand (UI-SPEC Screen 3 Empty State)
                        VStack(spacing: 16) {
                            Image(systemName: "tray")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("Noch keine Eintraege")
                                .font(.system(size: 22, weight: .semibold))
                            Text("Aktivitaeten erscheinen hier, sobald du deinen ersten Eintrag erfasst hast.")
                                .font(.system(size: 17))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    }
                } else {
                    ForEach(groupedByDay, id: \.date) { group in
                        Section(header: Text(group.dateLabel)) {
                            ForEach(group.entries) { entry in
                                ActivityRowView(
                                    entry: entry,
                                    category: category(for: entry)
                                )
                                // .swipeActions statt .onDelete (Pitfall 5 aus RESEARCH.md)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        entryToDelete = entry
                                        showDeleteConfirmation = true
                                    } label: {
                                        Label("Loeschen", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Verlauf")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await loadData()
            }
            // Delete Confirmation (UI-SPEC Copywriting Contract)
            .confirmationDialog("Eintrag loeschen",
                                isPresented: $showDeleteConfirmation,
                                titleVisibility: .visible) {
                Button("Loeschen", role: .destructive) {
                    if let entry = entryToDelete {
                        Task { try? await activityService.deleteActivity(id: entry.id) }
                    }
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Dieser Eintrag wird dauerhaft geloescht.")
            }
        }
    }

    // MARK: - Helpers

    private func category(for entry: ActivityEntry) -> CategoryConfig? {
        activityService.categories.first(where: { $0.id == entry.categoryId })
    }

    // Eintraege nach Tag gruppieren, absteigend sortiert — alle Familienmitglieder (DASH-05)
    private var groupedByDay: [DayGroup] {
        let sorted = activityService.todayEntries.sorted { $0.loggedAt > $1.loggedAt }
        let grouped = Dictionary(grouping: sorted) { entry in
            Calendar.current.startOfDay(for: entry.loggedAt)
        }
        return grouped.keys.sorted(by: >).map { date in
            DayGroup(
                date: date,
                dateLabel: date.formatted(.dateTime.weekday(.wide).day().month(.wide)),
                entries: grouped[date] ?? []
            )
        }
    }

    private func loadData() async {
        do {
            try await activityService.fetchTodayData()
            try await activityService.fetchAllTimeStats()  // DASH-04
        } catch {
            // Fehler bereits in activityService.activityError gesetzt
        }
    }
}

// MARK: - Helper Struct

private struct DayGroup {
    let date: Date
    let dateLabel: String
    let entries: [ActivityEntry]
}

#Preview {
    ActivityListView()
        .environmentObject(ActivityService())
}
