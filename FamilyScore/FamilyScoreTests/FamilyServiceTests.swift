// FamilyScoreTests/FamilyServiceTests.swift
// Target Membership: FamilyScoreTests
// STUBS -- Wave 1 (Plan 02) implementiert FamilyService; diese Tests werden dann gruen
// Anforderungen: FAM-01, FAM-02, FAM-03, FAM-04, FAM-05, KID-01

import XCTest
@testable import FamilyScore

@MainActor
final class FamilyServiceTests: XCTestCase {

    var mock: MockFamilyService!

    override func setUp() async throws {
        mock = MockFamilyService()
    }

    override func tearDown() async throws {
        mock = nil
    }

    // FAM-01: createFamily() setzt currentFamily auf non-nil
    func testCreateFamilySetsCurrentFamily() async throws {
        XCTAssertNil(mock.currentFamily)
        let familyId = try await mock.createFamily(name: "Muster-Familie")
        XCTAssertNotNil(mock.currentFamily)
        XCTAssertEqual(mock.currentFamily?.id, familyId)
        XCTAssertEqual(mock.currentFamily?.name, "Muster-Familie")
        XCTAssertEqual(mock.createFamilyCallCount, 1)
    }

    // FAM-01: createFamily() wirft Fehler wenn shouldThrowOnCreateFamily = true
    // (simuliert "User gehoert bereits einer Familie an")
    func testCreateFamilyThrowsWhenAlreadyInFamily() async throws {
        mock.shouldThrowOnCreateFamily = true
        do {
            _ = try await mock.createFamily(name: "Zweite Familie")
            XCTFail("Sollte Fehler werfen")
        } catch {
            XCTAssertNil(mock.currentFamily, "currentFamily darf bei Fehler nicht gesetzt werden")
        }
    }

    // FAM-02: generateInvite() gibt non-empty 8-stelligen Code zurueck
    func testGenerateInviteReturnsCode() async throws {
        let testFamily = Family(id: UUID(), name: "Test", created_at: Date(), created_by: nil)
        mock.setCurrentFamily(testFamily)
        let code = try await mock.generateInvite(familyId: testFamily.id, role: .adult)
        XCTAssertFalse(code.isEmpty, "Invite-Code darf nicht leer sein")
        XCTAssertEqual(code.count, 8, "Invite-Code sollte 8 Zeichen haben")
        XCTAssertEqual(mock.generateInviteCallCount, 1)
    }

    // FAM-02: joinFamily() mit gueltigem Token setzt currentFamily
    func testJoinFamilyWithValidTokenSetsFamily() async throws {
        let token = "ABCD1234"
        let familyId = try await mock.joinFamily(token: token)
        XCTAssertNotNil(mock.currentFamily)
        XCTAssertEqual(mock.currentFamily?.id, familyId)
        XCTAssertEqual(mock.lastJoinToken, token)
        XCTAssertEqual(mock.joinFamilyCallCount, 1)
    }

    // FAM-02: joinFamily() mit ungueltigem Token wirft Fehler
    func testJoinFamilyWithInvalidTokenThrows() async throws {
        mock.shouldThrowOnJoinFamily = true
        do {
            _ = try await mock.joinFamily(token: "INVALID1")
            XCTFail("Sollte Fehler werfen")
        } catch {
            XCTAssertNil(mock.currentFamily, "currentFamily darf bei Fehler nicht gesetzt werden")
        }
    }

    // FAM-03: removeMember() entfernt Mitglied aus members-Array
    func testRemoveMemberRemovesMemberFromList() async throws {
        let memberId = UUID()
        let member = FamilyMember(
            id: memberId, family_id: UUID(),
            display_name: "Test User", avatar_color: "#FF0000",
            role: "adult", created_at: Date()
        )
        mock.setMembers([member])
        XCTAssertEqual(mock.members.count, 1)
        try await mock.removeMember(memberId: memberId)
        XCTAssertEqual(mock.members.count, 0)
        XCTAssertEqual(mock.removeMemberCallCount, 1)
        XCTAssertEqual(mock.lastRemovedMemberId, memberId)
    }

    // FAM-03: removeMember() wirft Fehler wenn keine Admin-Berechtigung
    func testRemoveMemberThrowsWithoutAdminPermission() async throws {
        mock.shouldThrowOnRemoveMember = true
        let memberId = UUID()
        let member = FamilyMember(
            id: memberId, family_id: UUID(),
            display_name: "Test", avatar_color: "#FF0000",
            role: "adult", created_at: Date()
        )
        mock.setMembers([member])
        do {
            try await mock.removeMember(memberId: memberId)
            XCTFail("Sollte Fehler werfen")
        } catch {
            XCTAssertEqual(mock.members.count, 1, "Mitglied darf bei Fehler nicht entfernt werden")
        }
    }

    // FAM-04: changeMemberRole() speichert die neue Rolle
    func testChangeMemberRoleUpdatesRole() async throws {
        let memberId = UUID()
        try await mock.changeMemberRole(memberId: memberId, role: .admin)
        XCTAssertEqual(mock.lastChangedRole, .admin)
        XCTAssertEqual(mock.changeMemberRoleCallCount, 1)
    }

    // FAM-04: changeMemberRole() wirft Fehler ohne Admin-Berechtigung
    func testChangeMemberRoleThrowsWithoutAdminPermission() async throws {
        mock.shouldThrowOnChangeMemberRole = true
        do {
            try await mock.changeMemberRole(memberId: UUID(), role: .admin)
            XCTFail("Sollte Fehler werfen")
        } catch {
            // Erwartet: insufficientPermissions
            XCTAssertNil(mock.lastChangedRole, "Rolle darf bei Fehler nicht gesetzt werden")
        }
    }

    // KID-01: createChildProfile() fuegt Profil zu childProfiles hinzu
    func testCreateChildProfileAddsToChildProfiles() async throws {
        let testFamily = Family(id: UUID(), name: "Test", created_at: Date(), created_by: nil)
        mock.setCurrentFamily(testFamily)
        XCTAssertEqual(mock.childProfiles.count, 0)
        let profileId = try await mock.createChildProfile(name: "Emma", avatarColor: "#FF9500")
        XCTAssertEqual(mock.childProfiles.count, 1)
        XCTAssertEqual(mock.childProfiles.first?.display_name, "Emma")
        XCTAssertEqual(mock.childProfiles.first?.id, profileId)
        XCTAssertEqual(mock.createChildProfileCallCount, 1)
    }

    // FAM-05: updateProfile() wird aufgerufen ohne Fehler
    func testUpdateProfileCallsService() async throws {
        try await mock.updateProfile(displayName: "Max Mustermann", avatarColor: "#007AFF")
        XCTAssertEqual(mock.updateProfileCallCount, 1)
    }
}
