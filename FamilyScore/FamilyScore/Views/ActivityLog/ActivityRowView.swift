// FamilyScore/Views/ActivityLog/ActivityRowView.swift
// Target Membership: FamilyScore (App) ONLY
// HStack-Row-Muster analog zu LoginView.swift Error-Banner
// Accessibility: accessibilityElement(children: .ignore) + accessibilityLabel auf Row-Ebene

import SwiftUI

struct ActivityRowView: View {
    let entry: ActivityEntry
    let category: CategoryConfig?

    var body: some View {
        HStack(spacing: 12) {
            // Leading: SF Symbol in Ring-Farbe (UI-SPEC Screen 3)
            Image(systemName: category?.sfSymbol ?? "circle.fill")
                .foregroundStyle(ringColor)
                .frame(width: 20, height: 20)

            // Primaer: Kategoriename (Body) + Dauer/Punkte (Label)
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.system(size: 17))   // Body
                Text("\(entry.durationMinutes) min · \(Int(entry.points)) Punkte")
                    .font(.system(size: 13))   // Label
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Trailing: Zeitstempel (Label, tertiaryLabel)
            Text(entry.loggedAt, style: .time)
                .font(.system(size: 13))
                .foregroundStyle(Color(UIColor.tertiaryLabel))
        }
        .frame(minHeight: 44)  // iOS HIG Touch Target
        // Accessibility (UI-SPEC Accessibility Contract)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(displayName), \(entry.durationMinutes) Minuten, \(Int(entry.points)) Punkte, \(entry.loggedAt.formatted(date: .omitted, time: .shortened))")
    }

    private var displayName: String {
        if let title = entry.title, !title.isEmpty {
            return title
        }
        return category?.name ?? "Aktivitaet"
    }

    private var ringColor: Color {
        switch category?.ringType {
        case .duty:    return Color(UIColor.systemRed)
        case .leisure: return Color(UIColor.systemGreen)
        case .none:    return Color(UIColor.systemBlue)
        }
    }
}
