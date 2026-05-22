// FamilyScore/Views/Dashboard/RingClusterView.swift
// Target Membership: FamilyScore (App) ONLY
// Drei konzentrische Ringe — Apple Activity/Fitness Stil

import SwiftUI

struct RingClusterView: View {
    let dutyProgress: Double      // Pflicht-Ring (systemRed, aussen)
    let leisureProgress: Double   // Freizeit-Ring (systemGreen, mitte)
    let scoreProgress: Double     // Score-Ring (systemBlue, innen)
    let totalScore: Int

    // Ring-Groessen per UI-SPEC Ring Layout Contract
    // outerDiameter=280, lineWidth=20, gap=8 (sm spacing token)
    private let outerDiameter: CGFloat = 280
    private let gap: CGFloat = 8
    private let lineWidth: CGFloat = 20

    var body: some View {
        ZStack {
            // Pflicht-Ring (aussen, systemRed)
            SingleRingView(progress: dutyProgress, color: Color(UIColor.systemRed))
                .frame(width: outerDiameter, height: outerDiameter)
                .accessibilityLabel("Pflicht-Ring: \(Int(dutyProgress * 60)) von 60 Punkten (\(Int(dutyProgress * 100))%)")

            // Freizeit-Ring (mitte, systemGreen)
            // Diameter = 280 - 2*(20+8) = 224pt
            SingleRingView(progress: leisureProgress, color: Color(UIColor.systemGreen))
                .frame(width: outerDiameter - 2 * (lineWidth + gap),
                       height: outerDiameter - 2 * (lineWidth + gap))
                .accessibilityLabel("Freizeit-Ring: \(Int(leisureProgress * 60)) von 60 Punkten (\(Int(leisureProgress * 100))%)")

            // Score-Ring (innen, systemBlue)
            // Diameter = 280 - 4*(20+8) = 168pt
            SingleRingView(progress: scoreProgress, color: Color(UIColor.systemBlue))
                .frame(width: outerDiameter - 4 * (lineWidth + gap),
                       height: outerDiameter - 4 * (lineWidth + gap))
                .accessibilityLabel("Score-Ring: \(Int(scoreProgress * 60)) von 60 Punkten (\(Int(scoreProgress * 100))%)")

            // Zentrum: Tagesscore (Display + Label Typography — UI-SPEC)
            VStack(spacing: 2) {
                Text("\(totalScore)")
                    .font(.system(size: 34, weight: .semibold))  // Display
                    .monospacedDigit()
                Text("Punkte heute")
                    .font(.system(size: 13))                      // Label
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(totalScore) Punkte heute")
        }
        // Spring-Animation fuer Apple-Fitness-Feeling (UI-SPEC Interaction Contract)
        .animation(.spring(response: 0.6, dampingFraction: 0.75), value: dutyProgress)
        .animation(.spring(response: 0.6, dampingFraction: 0.75), value: leisureProgress)
        .animation(.spring(response: 0.6, dampingFraction: 0.75), value: scoreProgress)
    }
}

#Preview {
    RingClusterView(dutyProgress: 0.4, leisureProgress: 0.6, scoreProgress: 1.2, totalScore: 72)
        .padding()
}
