// FamilyScore/Views/Dashboard/WeekSummaryView.swift
// Target Membership: FamilyScore (App) ONLY
// Swift Charts — iOS 16 nativ (kein Third-Party)
// DASH-03: weeklyLeaderName fuer Wochensieger-Heading

import SwiftUI
import Charts

struct WeekSummaryView: View {
    let weekScores: [WeekMemberScore]
    let weeklyLeaderName: String?  // DASH-03: nil wenn noch keine Daten

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Diese Woche")
                .font(.system(size: 22, weight: .semibold))
                .padding(.horizontal, 16)

            // DASH-03: Wochensieger-Label (ROADMAP SC-6)
            if let leader = weeklyLeaderName {
                Text("Wochensieger: \(leader)")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(UIColor.systemBlue))
                    .padding(.horizontal, 16)
            }

            if weekScores.isEmpty {
                Text("Noch keine Wochendaten")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
            } else {
                Chart(weekScores) { score in
                    BarMark(
                        x: .value("Mitglied", score.memberName),
                        y: .value("Minuten", score.minutes)
                    )
                    .foregroundStyle(by: .value("Kategorie", score.category))
                    .position(by: .value("Kategorie", score.category), axis: .horizontal)
                }
                .chartForegroundStyleScale([
                    "Pflicht": Color(UIColor.systemRed),
                    "Freizeit": Color(UIColor.systemGreen)
                ])
                .frame(height: 200)
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 16)
    }
}

#Preview {
    WeekSummaryView(
        weekScores: [
            WeekMemberScore(memberName: "Max", category: "Pflicht", minutes: 120),
            WeekMemberScore(memberName: "Max", category: "Freizeit", minutes: 60),
            WeekMemberScore(memberName: "Anna", category: "Pflicht", minutes: 90)
        ],
        weeklyLeaderName: "Max"
    )
}
