// FamilyScore/Views/Dashboard/SingleRingView.swift
// Target Membership: FamilyScore (App) ONLY
// Kein Canvas, kein Custom Shape — Circle().trim() ist idiomatisch (RESEARCH.md Pattern 1)
// iOS 16 kompatibel — kein API nach iOS 16

import SwiftUI

struct SingleRingView: View {
    let progress: Double     // 0.0–1.0+ (Ueberlauf erlaubt, UI-SPEC)
    let color: Color
    let lineWidth: CGFloat = 20   // UI-SPEC: fix 20pt — hardware-independent

    var body: some View {
        ZStack {
            // Track (Hintergrund-Arc) — 15% Opacity (UI-SPEC)
            Circle()
                .stroke(color.opacity(0.15),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            // Progress-Arc (erste Runde)
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))   // 12-Uhr-Start (UI-SPEC)

            // Zweite Runde bei Ueberlauf (UI-SPEC: "slight opacity reduction on second lap")
            if progress > 1.0 {
                Circle()
                    .trim(from: 0, to: progress - 1.0)
                    .stroke(color.opacity(0.6),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        // Accessibility: Label wird von RingClusterView gesetzt — diese View versteckt sich
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 16) {
        SingleRingView(progress: 0.0, color: Color(UIColor.systemRed))
            .frame(width: 100, height: 100)
        SingleRingView(progress: 0.75, color: Color(UIColor.systemGreen))
            .frame(width: 100, height: 100)
        SingleRingView(progress: 1.5, color: Color(UIColor.systemBlue))
            .frame(width: 100, height: 100)
    }
    .padding()
}
