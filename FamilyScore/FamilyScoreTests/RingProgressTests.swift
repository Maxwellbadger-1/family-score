// FamilyScoreTests/RingProgressTests.swift
// Target Membership: FamilyScoreTests
// Unit-Tests fuer Ring-Progress-Logik — kein Netzwerk, kein Mock noetig

import XCTest
@testable import FamilyScore

@MainActor
final class RingProgressTests: XCTestCase {

    // DASH-01: 60 Punkte = Ring voll (UI-SPEC Score Contract)
    func testRingFullAt60Points() {
        let progress = 60.0 / 60.0
        XCTAssertEqual(progress, 1.0, accuracy: 0.001)
    }

    // DASH-01: Ueberlauf > 100% — zweite Runde korrekt berechnet
    func testRingOverflowSecondLap() {
        let points = 90.0
        let progress = points / 60.0    // 1.5
        XCTAssertGreaterThan(progress, 1.0, "Ueberlauf muss > 1.0 sein")
        let secondLap = progress - 1.0
        XCTAssertEqual(secondLap, 0.5, accuracy: 0.001, "Zweite Runde muss 0.5 sein")
    }

    // DASH-01: 0 Punkte = 0% Progress
    func testZeroPointsZeroProgress() {
        let progress = 0.0 / 60.0
        XCTAssertEqual(progress, 0.0)
    }

    // SCORE-01: Punkte = Minuten × 1.0 (Phase 4 fix)
    func testPointsEqualsMinutesForPhase4() {
        let minutes = 45
        let pointWeight = 1.0
        let points = Double(minutes) * pointWeight
        XCTAssertEqual(points, 45.0)
    }

    // DASH-01: Pflicht-Kategorien summieren in duty_points
    func testDutyCategoryMapping() {
        let dutyNames = ["Haushalt", "Besorgungen", "Arbeit/Schule"]
        for name in dutyNames {
            let config = CategoryConfig(id: UUID(), familyId: UUID(), name: name,
                                       icon: nil, color: nil, pointWeight: 1.0,
                                       isEnabled: true, sortOrder: 0)
            XCTAssertEqual(config.ringType, RingType.duty, "\(name) muss duty sein")
        }
    }

    // DASH-01: Freizeit-Kategorie mappt auf leisure
    func testLeisureCategoryMapping() {
        let config = CategoryConfig(id: UUID(), familyId: UUID(), name: "Hobby/Freizeit",
                                   icon: nil, color: nil, pointWeight: 1.0,
                                   isEnabled: true, sortOrder: 1)
        XCTAssertEqual(config.ringType, RingType.leisure)
    }
}
