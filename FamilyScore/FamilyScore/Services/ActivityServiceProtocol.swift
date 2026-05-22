// FamilyScore/Services/ActivityServiceProtocol.swift
// Target Membership: FamilyScore (App) ONLY
// Alle Phase-4-Model-Typen + ActivityServiceProtocol in einer Datei
// Wave 0 — Protocol-First, Implementation folgt in Wave 1

import Foundation

// MARK: - Enums

enum RingType { case duty, leisure }

// MARK: - Model: ActivityEntry

/// Vollstaendiger Eintrag aus activity_entries (READ)
struct ActivityEntry: Codable, Identifiable, Sendable {
    let id: UUID
    let familyId: UUID
    let userId: UUID
    let categoryId: UUID
    let durationMinutes: Int
    let points: Double
    let title: String?
    let loggedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, points
        case familyId = "family_id"
        case userId = "user_id"
        case categoryId = "category_id"
        case durationMinutes = "duration_minutes"
        case loggedAt = "logged_at"
    }
}

/// Encodable-only Struct fuer INSERT in activity_entries
struct NewActivityEntry: Encodable, Sendable {
    let familyId: UUID
    let userId: UUID
    let categoryId: UUID
    let durationMinutes: Int
    let points: Double
    let title: String?

    enum CodingKeys: String, CodingKey {
        case familyId = "family_id"
        case userId = "user_id"
        case categoryId = "category_id"
        case durationMinutes = "duration_minutes"
        case points, title
    }
}

// MARK: - Model: CategoryConfig

struct CategoryConfig: Codable, Identifiable, Sendable {
    let id: UUID
    let familyId: UUID
    let name: String
    let icon: String?
    let color: String?
    let pointWeight: Double
    let isEnabled: Bool
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, name, icon, color
        case familyId = "family_id"
        case pointWeight = "point_weight"
        case isEnabled = "is_enabled"
        case sortOrder = "sort_order"
    }
}

extension CategoryConfig {
    var ringType: RingType {
        switch name {
        case "Haushalt", "Besorgungen", "Arbeit/Schule": return .duty
        case "Hobby/Freizeit": return .leisure
        default: return .duty
        }
    }

    var sfSymbol: String {
        switch name {
        case "Haushalt": return "house.fill"
        case "Besorgungen": return "cart.fill"
        case "Arbeit/Schule": return "briefcase.fill"
        case "Hobby/Freizeit": return "gamecontroller.fill"
        default: return "circle.fill"
        }
    }
}

// MARK: - Model: DayScore (RPC-Ergebnis get_today_score)

struct DayScore: Decodable, Sendable {
    let dutyMinutes: Int
    let dutyPoints: Double
    let leisureMinutes: Int
    let leisurePoints: Double
    let totalPoints: Double

    enum CodingKeys: String, CodingKey {
        case dutyMinutes = "duty_minutes"
        case dutyPoints = "duty_points"
        case leisureMinutes = "leisure_minutes"
        case leisurePoints = "leisure_points"
        case totalPoints = "total_points"
    }
}

// MARK: - Model: MemberDayScore (RPC-Ergebnis get_family_today_scores)

struct MemberDayScore: Decodable, Identifiable, Sendable {
    let userId: UUID
    let displayName: String
    let avatarColor: String
    let dutyPoints: Double
    let leisurePoints: Double
    let totalPoints: Double

    var id: UUID { userId }

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case avatarColor = "avatar_color"
        case dutyPoints = "duty_points"
        case leisurePoints = "leisure_points"
        case totalPoints = "total_points"
        case userId = "user_id"
    }
}

// MARK: - Model: WeekMemberScore (fuer Swift Charts)

struct WeekMemberScore: Identifiable, Sendable {
    let id = UUID()
    let memberName: String
    let category: String    // "Pflicht" oder "Freizeit"
    let minutes: Int
}

// MARK: - Model: WeeklySummary (aus weekly_summaries Tabelle)

struct WeeklySummary: Decodable, Identifiable, Sendable {
    let id: UUID
    let familyId: UUID
    let userId: UUID
    let weekStart: Date
    let totalMinutes: Int
    let totalPoints: Double
    let byCategory: [String: CategoryBreakdown]?

    enum CodingKeys: String, CodingKey {
        case id
        case familyId = "family_id"
        case userId = "user_id"
        case weekStart = "week_start"
        case totalMinutes = "total_minutes"
        case totalPoints = "total_points"
        case byCategory = "by_category"
    }
}

struct CategoryBreakdown: Decodable, Sendable {
    let minutes: Int
    let points: Double
}

// MARK: - Model: AllTimeStats (DASH-04 — Gesamt seit App-Start)

/// SELECT SUM() auf activity_entries ohne Datumsfilter — kein neues Schema noetig (RESEARCH.md DASH-04)
struct AllTimeStats: Sendable {
    let totalHours: Double
    let totalPoints: Double
}

// MARK: - Protocol

/// ActivityServiceProtocol — definiert den vollstaendigen Vertrag fuer ActivityService.
/// Target: FamilyScore (App). MockActivityService conformt via @testable import.
/// Analogon: AuthServiceProtocol in MockAuthService.swift (Phase 2 Muster).
@MainActor
protocol ActivityServiceProtocol: AnyObject {
    // State (read-only)
    var todayEntries: [ActivityEntry] { get }
    var categories: [CategoryConfig] { get }
    var dayScore: DayScore? { get }
    var weeklyScores: [WeeklySummary] { get }
    var familyDayScores: [MemberDayScore] { get }
    var dutyProgress: Double { get }
    var leisureProgress: Double { get }
    var scoreProgress: Double { get }
    var totalScore: Int { get }
    var timerIsRunning: Bool { get }
    var allTimeStats: AllTimeStats? { get }  // DASH-04

    // Error (read-write: UI kann nach Anzeige nil setzen)
    var activityError: String? { get set }

    // Methoden
    func fetchTodayData() async throws
    func fetchAllTimeStats() async throws  // DASH-04: SUM() ohne Datumsfilter
    func fetchFamilyData() async throws
    func fetchWeeklyData() async throws
    func logActivity(categoryId: UUID, durationMinutes: Int, title: String?) async throws
    func logActivityForChild(childUserId: UUID, categoryId: UUID, durationMinutes: Int, title: String?) async throws
    func deleteActivity(id: UUID) async throws
    func startTimer(categoryId: UUID)
    func stopTimer(title: String?) async throws
}
