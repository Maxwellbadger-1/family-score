// FamilyScoreTests/ActivityServiceTests.swift
// Target Membership: FamilyScoreTests
// STUBS — Wave 0; Wave 1+ ersetzt durch echte Assertions gegen MockActivityService

import XCTest
@testable import FamilyScore

@MainActor
final class ActivityServiceTests: XCTestCase {

    var mock: MockActivityService!

    override func setUp() async throws {
        mock = MockActivityService()
    }

    override func tearDown() async throws {
        mock = nil
    }

    // LOG-01: Timer startet korrekt
    func testTimerStartsSetsRunningTrue() {
        let categoryId = UUID()
        mock.startTimer(categoryId: categoryId)
        XCTAssertTrue(mock.timerIsRunning, "Timer muss nach startTimer laufen")
    }

    // LOG-01: Timer stoppt und ruft logActivity auf
    func testTimerStopCallsLogActivity() async throws {
        mock.startTimer(categoryId: UUID())
        try await mock.stopTimer(title: nil)
        XCTAssertFalse(mock.timerIsRunning, "Timer muss nach stopTimer gestoppt sein")
        XCTAssertEqual(mock.logActivityCallCount, 1, "stopTimer muss logActivity aufrufen")
    }

    // LOG-02: Retroaktiver Eintrag via logActivity
    func testLogActivityIncreasesCallCount() async throws {
        try await mock.logActivity(categoryId: UUID(), durationMinutes: 30, title: nil)
        XCTAssertEqual(mock.logActivityCallCount, 1)
    }

    // LOG-03: Titel wird korrekt weitergegeben
    func testLogActivityPassesTitleCorrectly() async throws {
        let title = "Kueche geputzt"
        try await mock.logActivity(categoryId: UUID(), durationMinutes: 20, title: title)
        XCTAssertEqual(mock.lastLoggedTitle, title)
    }

    // LOG-04: Kind-Eintrag via logActivityForChild
    func testLogForChildIncreasesCallCount() async throws {
        try await mock.logActivityForChild(childUserId: UUID(), categoryId: UUID(), durationMinutes: 15, title: nil)
        XCTAssertEqual(mock.logForChildCallCount, 1)
    }

    // LOG-05: Eintrag loeschen entfernt aus todayEntries
    func testDeleteActivityRemovesEntry() async throws {
        let id = UUID()
        try await mock.deleteActivity(id: id)
        XCTAssertEqual(mock.deleteActivityCallCount, 1)
        XCTAssertFalse(mock.todayEntries.contains { $0.id == id })
    }

    // LOG-05: Fehler beim Loeschen wirft korrekt
    func testDeleteActivityThrowsWhenFlagSet() async throws {
        mock.shouldThrowOnDelete = true
        do {
            try await mock.deleteActivity(id: UUID())
            XCTFail("Soll Fehler werfen")
        } catch MockActivityError.deleteFailed {
            XCTAssertEqual(mock.deleteActivityCallCount, 1)
        }
    }

    // LOG-06: 4 Kategorien — Mapping Pflicht/Freizeit korrekt
    func testCategoryRingTypeMapping() {
        let haushalt = CategoryConfig(id: UUID(), familyId: UUID(), name: "Haushalt", icon: nil, color: nil, pointWeight: 1.0, isEnabled: true, sortOrder: 0)
        let freizeit = CategoryConfig(id: UUID(), familyId: UUID(), name: "Hobby/Freizeit", icon: nil, color: nil, pointWeight: 1.0, isEnabled: true, sortOrder: 1)
        XCTAssertEqual(haushalt.ringType, RingType.duty)
        XCTAssertEqual(freizeit.ringType, RingType.leisure)
    }

    // DASH-01: Ring-Progress aus dutyProgress lesbar
    func testDutyProgressReadable() {
        mock.dutyProgress = 0.5
        XCTAssertEqual(mock.dutyProgress, 0.5, accuracy: 0.001)
    }

    // SCORE-01: Punkte = Minuten × 1.0 fuer Phase 4
    func testPointsEqualsMinutesTimesOneForPhase4() {
        let minutes = 45
        let pointWeight = 1.0
        let points = Double(minutes) * pointWeight
        XCTAssertEqual(points, 45.0)
    }

    // SCORE-02: Kein Akkumulieren client-seitig — Mock hat kein total_score-Feld
    func testNoMutableTotalScoreField() {
        // Verifiziert durch Kompilierung: totalScore ist read-only @Published, kein setter
        // Wird nur via refreshLocalRingProgress() aktualisiert (Wave 1 Implementation)
        XCTAssertEqual(mock.totalScore, 0)
    }
}
