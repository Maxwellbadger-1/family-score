// FamilyScoreTests/Mocks/MockFamilyService.swift
// Target Membership: FamilyScoreTests ONLY
// iOS 16.0 Minimum: ObservableObject + @Published (KEIN @Observable)

import Foundation
import Combine
@testable import FamilyScore

// MARK: - Protocol (definiert den Vertrag; Wave 1 FamilyService implementiert ihn)

@MainActor
protocol FamilyServiceProtocol: AnyObject {
    var currentFamily: Family? { get }
    var members: [FamilyMember] { get }
    var childProfiles: [ChildProfile] { get }
    var serviceError: String? { get set }
    func createFamily(name: String) async throws -> UUID
    func joinFamily(token: String) async throws -> UUID
    func fetchFamily(familyId: UUID) async
    func fetchMembers(familyId: UUID) async
    func fetchChildProfiles(familyId: UUID) async
    func generateInvite(familyId: UUID, role: MemberRole) async throws -> String
    func removeMember(memberId: UUID) async throws
    func changeMemberRole(memberId: UUID, role: MemberRole) async throws
    func updateProfile(displayName: String, avatarColor: String) async throws
    func createChildProfile(name: String, avatarColor: String) async throws -> UUID
}

// MARK: - Mock-Implementierung

@MainActor
final class MockFamilyService: ObservableObject, FamilyServiceProtocol {

    @Published private(set) var currentFamily: Family?
    @Published private(set) var members: [FamilyMember] = []
    @Published private(set) var childProfiles: [ChildProfile] = []
    @Published var serviceError: String? = nil

    // Verhalten-Flags fuer Unit-Tests (Muster aus MockAuthService)
    var shouldThrowOnCreateFamily: Bool = false
    var shouldThrowOnJoinFamily: Bool = false
    var shouldThrowOnRemoveMember: Bool = false
    var shouldThrowOnChangeMemberRole: Bool = false
    var shouldThrowOnCreateChildProfile: Bool = false

    // Aufruf-Zaehler fuer Assertions
    var createFamilyCallCount: Int = 0
    var joinFamilyCallCount: Int = 0
    var fetchMembersCallCount: Int = 0
    var removeMemberCallCount: Int = 0
    var changeMemberRoleCallCount: Int = 0
    var generateInviteCallCount: Int = 0
    var createChildProfileCallCount: Int = 0
    var updateProfileCallCount: Int = 0

    // Letzte Parameter fuer Assertions
    var lastJoinToken: String? = nil
    var lastCreatedFamilyName: String? = nil
    var lastChangedRole: MemberRole? = nil
    var lastRemovedMemberId: UUID? = nil

    init(initialMembers: [FamilyMember] = [], initialFamily: Family? = nil) {
        self.members = initialMembers
        self.currentFamily = initialFamily
    }

    // Testhelfer: State direkt setzen
    func setCurrentFamily(_ family: Family?) { currentFamily = family }
    func setMembers(_ m: [FamilyMember]) { members = m }
    func setChildProfiles(_ cp: [ChildProfile]) { childProfiles = cp }

    // MARK: - Protocol-Implementierung

    func createFamily(name: String) async throws -> UUID {
        createFamilyCallCount += 1
        lastCreatedFamilyName = name
        if shouldThrowOnCreateFamily { throw MockFamilyError.createFailed }
        let id = UUID()
        currentFamily = Family(id: id, name: name, created_at: Date(), created_by: nil)
        return id
    }

    func joinFamily(token: String) async throws -> UUID {
        joinFamilyCallCount += 1
        lastJoinToken = token
        if shouldThrowOnJoinFamily { throw MockFamilyError.invalidToken }
        let id = UUID()
        currentFamily = Family(id: id, name: "Test Familie", created_at: Date(), created_by: nil)
        return id
    }

    func fetchFamily(familyId: UUID) async {
        // Mock: currentFamily unveraendert lassen (Test setzt via setCurrentFamily)
    }

    func fetchMembers(familyId: UUID) async {
        fetchMembersCallCount += 1
        // Mock: members unveraendert lassen (Test setzt via setMembers)
    }

    func fetchChildProfiles(familyId: UUID) async {
        // Mock: childProfiles unveraendert lassen
    }

    func generateInvite(familyId: UUID, role: MemberRole) async throws -> String {
        generateInviteCallCount += 1
        return "ABCD1234"  // 8-stelliger Mock-Code
    }

    func removeMember(memberId: UUID) async throws {
        removeMemberCallCount += 1
        lastRemovedMemberId = memberId
        if shouldThrowOnRemoveMember { throw MockFamilyError.insufficientPermissions }
        members = members.filter { $0.id != memberId }
    }

    func changeMemberRole(memberId: UUID, role: MemberRole) async throws {
        changeMemberRoleCallCount += 1
        if shouldThrowOnChangeMemberRole { throw MockFamilyError.insufficientPermissions }
        lastChangedRole = role
    }

    func updateProfile(displayName: String, avatarColor: String) async throws {
        updateProfileCallCount += 1
    }

    func createChildProfile(name: String, avatarColor: String) async throws -> UUID {
        createChildProfileCallCount += 1
        if shouldThrowOnCreateChildProfile { throw MockFamilyError.createFailed }
        let id = UUID()
        let profile = ChildProfile(
            id: id,
            family_id: currentFamily?.id ?? UUID(),
            display_name: name,
            avatar_color: avatarColor,
            created_by: UUID(),
            created_at: Date()
        )
        childProfiles.append(profile)
        return id
    }
}

// MARK: - Fehler-Enum

enum MockFamilyError: Error, LocalizedError {
    case createFailed
    case invalidToken
    case insufficientPermissions
    case lastAdmin

    var errorDescription: String? {
        switch self {
        case .createFailed:            return "Familie konnte nicht erstellt werden."
        case .invalidToken:            return "Ungültiger oder abgelaufener Einladungscode."
        case .insufficientPermissions: return "Keine Admin-Berechtigung."
        case .lastAdmin:               return "Die Familie muss mindestens einen Admin haben."
        }
    }
}
