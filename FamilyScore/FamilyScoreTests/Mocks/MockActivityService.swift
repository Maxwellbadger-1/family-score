// FamilyScoreTests/Mocks/MockActivityService.swift
// Target Membership: FamilyScoreTests ONLY
import Foundation
import Combine
@testable import FamilyScore

@MainActor
final class MockActivityService: ObservableObject, ActivityServiceProtocol {

    @Published private(set) var todayEntries: [ActivityEntry] = []
    @Published private(set) var categories: [CategoryConfig] = []
    @Published private(set) var dayScore: DayScore? = nil
    @Published private(set) var weeklyScores: [WeeklySummary] = []
    @Published private(set) var familyDayScores: [MemberDayScore] = []
    @Published var dutyProgress: Double = 0.0
    @Published var leisureProgress: Double = 0.0
    @Published var scoreProgress: Double = 0.0
    @Published var totalScore: Int = 0
    @Published var activityError: String? = nil
    var timerIsRunning: Bool = false
    var allTimeStats: AllTimeStats? = nil

    // Verhaltens-Flags (Muster von MockAuthService)
    var shouldThrowOnLog: Bool = false
    var shouldThrowOnDelete: Bool = false
    var logActivityCallCount: Int = 0
    var deleteActivityCallCount: Int = 0
    var logForChildCallCount: Int = 0
    var lastLoggedCategoryId: UUID? = nil
    var lastLoggedDuration: Int = 0
    var lastLoggedTitle: String? = nil

    // Testhelfer
    func setEntries(_ entries: [ActivityEntry]) { todayEntries = entries }
    func setCategories(_ cats: [CategoryConfig]) { categories = cats }

    func fetchTodayData() async throws { /* Mock: kein Netzwerk */ }
    func fetchFamilyData() async throws { /* Mock: kein Netzwerk */ }
    func fetchWeeklyData() async throws { /* Mock: kein Netzwerk */ }
    func fetchAllTimeStats() async throws { /* Mock: kein Netzwerk */ }

    func logActivity(categoryId: UUID, durationMinutes: Int, title: String?) async throws {
        logActivityCallCount += 1
        lastLoggedCategoryId = categoryId
        lastLoggedDuration = durationMinutes
        lastLoggedTitle = title
        if shouldThrowOnLog { throw MockActivityError.logFailed }
    }

    func logActivityForChild(childUserId: UUID, categoryId: UUID, durationMinutes: Int, title: String?) async throws {
        logForChildCallCount += 1
        if shouldThrowOnLog { throw MockActivityError.logFailed }
    }

    func deleteActivity(id: UUID) async throws {
        deleteActivityCallCount += 1
        if shouldThrowOnDelete { throw MockActivityError.deleteFailed }
        todayEntries.removeAll { $0.id == id }
    }

    func startTimer(categoryId: UUID) { timerIsRunning = true }

    func stopTimer(title: String?) async throws {
        timerIsRunning = false
        try await logActivity(categoryId: UUID(), durationMinutes: 1, title: title)
    }
}

enum MockActivityError: Error {
    case logFailed
    case deleteFailed
}
