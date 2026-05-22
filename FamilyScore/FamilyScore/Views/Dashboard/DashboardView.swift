// FamilyScore/Views/Dashboard/DashboardView.swift
// Target Membership: FamilyScore (App) ONLY
// iOS 16: @EnvironmentObject, NavigationStack, .task, .sheet
// DASH-02: familyMemberRow zeigt dutyPoints + leisurePoints
// DASH-03: weeklyLeaderName berechnet aus weeklyScores.max(totalPoints)

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var activityService: ActivityService
    @State private var showingLogSheet: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Datum-Header (Label-Typo, systemSecondaryLabel — UI-SPEC Screen 1)
                    HStack {
                        Text(Date(), format: .dateTime.weekday(.wide).day().month(.wide))
                            .font(.system(size: 13))
                            .foregroundStyle(Color(UIColor.secondaryLabel))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // Ring-Cluster (Zentrum des Dashboards)
                    RingClusterView(
                        dutyProgress: activityService.dutyProgress,
                        leisureProgress: activityService.leisureProgress,
                        scoreProgress: activityService.scoreProgress,
                        totalScore: activityService.totalScore
                    )
                    .padding(.vertical, 24)

                    // Leerstand (UI-SPEC Copywriting Contract + Empty State)
                    if activityService.todayEntries.isEmpty {
                        VStack(spacing: 16) {
                            Text("Noch keine Aktivitaeten heute")
                                .font(.system(size: 22, weight: .semibold))  // Heading
                            Text("Tippe auf \u{201E}+\u{201C} um deinen ersten Eintrag zu starten.")
                                .font(.system(size: 17))                      // Body
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 24)
                    }

                    // Ring-Labels (horizontaler HStack unter dem Cluster)
                    HStack(spacing: 16) {
                        ringLabel("Pflicht", color: Color(UIColor.systemRed),
                                  value: Int(activityService.dutyProgress * 60))
                        ringLabel("Freizeit", color: Color(UIColor.systemGreen),
                                  value: Int(activityService.leisureProgress * 60))
                        ringLabel("Score", color: Color(UIColor.systemBlue),
                                  value: activityService.totalScore)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)

                    Divider().padding(.horizontal, 16)

                    // Familien-Uebersicht (DASH-02: Pflicht + Freizeit pro Mitglied)
                    if !activityService.familyDayScores.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Familie heute")
                                .font(.system(size: 22, weight: .semibold))  // Heading
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                            ForEach(activityService.familyDayScores) { member in
                                familyMemberRow(member)
                            }
                        }
                        Divider().padding(.horizontal, 16)
                    }

                    // Wochenbilanz mit Wochensieger (DASH-03)
                    WeekSummaryView(
                        weekScores: weekScoresForChart,
                        weeklyLeaderName: weeklyLeaderName
                    )
                    .padding(.bottom, 80) // Platz fuer FAB
                }
            }
            .navigationTitle("Uebersicht")
            .navigationBarTitleDisplayMode(.large)
            .task { await loadDashboard() }
            .alert("Fehler", isPresented: Binding(
                get: { activityService.activityError != nil },
                set: { if !$0 { activityService.activityError = nil } }
            )) {
                Button("Verstanden") { activityService.activityError = nil }
            } message: {
                Text(activityService.activityError ?? "")
            }
        }
        .overlay(alignment: .bottomTrailing) {
            // FAB — "+" Button, 56pt diameter, 24pt margin (UI-SPEC Screen 1)
            Button {
                showingLogSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color(UIColor.systemBlue))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Aktivitaet erfassen")
            .padding(.trailing, 24)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showingLogSheet) {
            ActivityLogSheet(activityService: activityService)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func ringLabel(_ name: String, color: Color, value: Int) -> some View {
        VStack(spacing: 2) {
            Circle()
                .stroke(color, lineWidth: 3)
                .frame(width: 10, height: 10)
            Text(name)
                .font(.system(size: 13))  // Label
                .foregroundStyle(.secondary)
            Text("\(value) pt")
                .font(.system(size: 13))  // Label
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func familyMemberRow(_ member: MemberDayScore) -> some View {
        HStack(spacing: 12) {
            // Mini Score-Ring (36pt) — DASH-02
            let progress = member.totalPoints / 60.0
            SingleRingView(progress: progress, color: Color(UIColor.systemBlue))
                .frame(width: 36, height: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName)
                    .font(.system(size: 17))  // Body
                // DASH-02: Pflicht- und Freizeit-Punkte anzeigen
                Text("Pflicht: \(Int(member.dutyPoints))pt \u{00B7} Freizeit: \(Int(member.leisurePoints))pt")
                    .font(.system(size: 13))  // Label
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(Int(member.totalPoints)) pt")
                .font(.system(size: 17))  // Body
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Daten-Transformation

    private var weekScoresForChart: [WeekMemberScore] {
        // weekly_summaries → WeekMemberScore fuer Swift Charts
        var result: [WeekMemberScore] = []
        for summary in activityService.weeklyScores {
            let breakdown = summary.byCategory ?? [:]
            let dutyMin = (breakdown["Haushalt"]?.minutes ?? 0)
                + (breakdown["Besorgungen"]?.minutes ?? 0)
                + (breakdown["Arbeit/Schule"]?.minutes ?? 0)
            let leisureMin = breakdown["Hobby/Freizeit"]?.minutes ?? 0
            let name = activityService.familyDayScores
                .first(where: { $0.userId == summary.userId })?.displayName ?? "Mitglied"
            if dutyMin > 0 {
                result.append(WeekMemberScore(memberName: name, category: "Pflicht", minutes: dutyMin))
            }
            if leisureMin > 0 {
                result.append(WeekMemberScore(memberName: name, category: "Freizeit", minutes: leisureMin))
            }
        }
        return result
    }

    // DASH-03: Wochensieger — Mitglied mit hoechstem totalPoints in weeklyScores
    private var weeklyLeaderName: String? {
        guard let leader = activityService.weeklyScores.max(by: { $0.totalPoints < $1.totalPoints }),
              leader.totalPoints > 0 else { return nil }
        return activityService.familyDayScores
            .first(where: { $0.userId == leader.userId })?.displayName
    }

    // MARK: - Datenladen

    private func loadDashboard() async {
        do {
            try await activityService.fetchTodayData()
            try await activityService.fetchFamilyData()
            try await activityService.fetchWeeklyData()
        } catch {
            // Fehler bereits in activityService.activityError gesetzt (im Service)
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(ActivityService())
}
