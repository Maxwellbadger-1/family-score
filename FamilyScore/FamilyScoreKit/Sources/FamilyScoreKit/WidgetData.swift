// Sources/FamilyScoreKit/WidgetData.swift
// Shared between App Target and Widget Extension
// KEIN Supabase SDK import — nur Foundation
import Foundation

public struct WidgetData: Codable, Sendable {
    public struct MemberScore: Codable, Sendable {
        public let displayName: String
        public let avatarInitial: String
        public let weeklyPoints: Double
        public let weeklyMinutes: Int

        public init(displayName: String, avatarInitial: String,
                    weeklyPoints: Double, weeklyMinutes: Int) {
            self.displayName = displayName
            self.avatarInitial = avatarInitial
            self.weeklyPoints = weeklyPoints
            self.weeklyMinutes = weeklyMinutes
        }
    }

    public let familyName: String
    public let members: [MemberScore]
    public let lastUpdated: Date

    public init(familyName: String, members: [MemberScore], lastUpdated: Date) {
        self.familyName = familyName
        self.members = members
        self.lastUpdated = lastUpdated
    }
}

// App Group Identifier — single source of truth für App und Widget
public let appGroupIdentifier = "group.com.familyscore"

// Placeholder für Widget-Previews und Snapshots
extension WidgetData {
    public static let placeholder = WidgetData(
        familyName: "Familie Muster",
        members: [
            MemberScore(displayName: "Max", avatarInitial: "M",
                        weeklyPoints: 120, weeklyMinutes: 90),
            MemberScore(displayName: "Anna", avatarInitial: "A",
                        weeklyPoints: 95, weeklyMinutes: 75)
        ],
        lastUpdated: Date()
    )
}
