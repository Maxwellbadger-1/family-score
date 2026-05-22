// FamilyScore/Services/FamilyService.swift
// Target Membership: FamilyScore (App) ONLY
// iOS 16.0 Minimum: ObservableObject + @Published (KEIN @Observable -- iOS 17+)
// NIEMALS Supabase SDK im Widget-Target -- gilt auch fuer diesen Service
// Threat mitigations: T-3-01, T-3-02, T-3-03, T-3-04, T-3-05, T-3-06, T-3-07

import Foundation
@preconcurrency import Supabase

@MainActor
final class FamilyService: ObservableObject {

    @Published private(set) var currentFamily: Family?
    @Published private(set) var members: [FamilyMember] = []
    @Published private(set) var childProfiles: [ChildProfile] = []
    @Published var serviceError: String? = nil

    // MARK: - Familie laden

    /// Lädt die eigene Familie anhand der family_id aus family_members des aktuellen Users.
    /// Wird in MemberListView aufgerufen wenn currentFamily noch nicht gesetzt ist.
    func fetchCurrentFamily() async {
        do {
            let userId = try await supabase.auth.session.user.id
            struct Row: Decodable { let family_id: UUID? }
            let rows: [Row] = try await supabase
                .from("family_members")
                .select("family_id")
                .eq("id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value
            guard let familyId = rows.first?.family_id else { return }
            await fetchFamily(familyId: familyId)
        } catch {
            serviceError = "Familie konnte nicht geladen werden."
        }
    }

    func fetchFamily(familyId: UUID) async {
        do {
            let family: Family = try await supabase
                .from("families")
                .select()
                .eq("id", value: familyId.uuidString)
                .single()
                .execute()
                .value
            currentFamily = family
        } catch {
            serviceError = "Familie konnte nicht geladen werden."
        }
    }

    func fetchMembers(familyId: UUID) async {
        do {
            let fetched: [FamilyMember] = try await supabase
                .from("family_members")
                .select()
                .eq("family_id", value: familyId.uuidString)
                .order("created_at", ascending: true)
                .execute()
                .value
            members = fetched
        } catch {
            serviceError = "Mitglieder konnten nicht geladen werden."
        }
    }

    func fetchChildProfiles(familyId: UUID) async {
        do {
            let fetched: [ChildProfile] = try await supabase
                .from("child_profiles")
                .select()
                .eq("family_id", value: familyId.uuidString)
                .order("created_at", ascending: true)
                .execute()
                .value
            childProfiles = fetched
        } catch {
            serviceError = "Kinder-Profile konnten nicht geladen werden."
        }
    }

    // MARK: - Familie erstellen und beitreten

    /// T-3-07: create_family RPC prueft serverseitig ob User bereits einer Familie angehoert.
    /// Kein Client-seitiger Admin-Check — SECURITY DEFINER RPC uebernimmt das.
    func createFamily(name: String) async throws -> UUID {
        struct Params: Encodable {
            let familyName: String
            enum CodingKeys: String, CodingKey { case familyName = "family_name" }
        }
        do {
            let familyId: UUID = try await supabase
                .rpc("create_family", params: Params(familyName: name))
                .execute()
                .value
            return familyId
        } catch {
            let msg = error.localizedDescription.lowercased()
            if msg.contains("bereits einer familie") || msg.contains("already") {
                throw FamilyServiceError.alreadyInFamily
            }
            throw FamilyServiceError.unknown(error.localizedDescription)
        }
    }

    /// T-3-02: accept_invite RPC prueft used_by IS NULL serverseitig (kein Replay moeglich).
    /// T-3-03: Ablaufdatum-Pruefung ausschliesslich serverseitig (expires_at > now()) -- kein Client-Clock-Vergleich.
    func joinFamily(token: String) async throws -> UUID {
        struct Params: Encodable {
            let inviteToken: String
            enum CodingKeys: String, CodingKey { case inviteToken = "invite_token" }
        }
        do {
            let familyId: UUID = try await supabase
                .rpc("accept_invite", params: Params(inviteToken: token))
                .execute()
                .value
            return familyId
        } catch {
            let msg = error.localizedDescription.lowercased()
            if msg.contains("ungültig") || msg.contains("abgelaufen") || msg.contains("invalid") || msg.contains("expired") {
                throw FamilyServiceError.invalidToken
            }
            if msg.contains("bereits einer familie") || msg.contains("already") {
                throw FamilyServiceError.alreadyInFamily
            }
            throw FamilyServiceError.unknown(error.localizedDescription)
        }
    }

    // MARK: - Einladung generieren (Admin only via RLS)

    /// Token-Generierung IMMER serverseitig (gen_random_bytes DB-Default).
    /// Admin-only via RLS Policy "Admin verwaltet Einladungen" (Phase 1).
    /// T-3-04: currentUserId wird aus echtem JWT gelesen -- kein Client-seitiges Trust.
    func generateInvite(familyId: UUID, role: MemberRole) async throws -> String {
        struct NewInvite: Encodable {
            let family_id: String
            let created_by: String
            let role: String
        }
        struct InviteResponse: Decodable { let token: String }

        let currentUserId: UUID
        do {
            currentUserId = try await supabase.auth.session.user.id
        } catch {
            throw FamilyServiceError.notAuthenticated
        }

        let response: InviteResponse = try await supabase
            .from("family_invites")
            .insert(NewInvite(
                family_id: familyId.uuidString,
                created_by: currentUserId.uuidString,
                role: role.rawValue
            ))
            .select("token")
            .single()
            .execute()
            .value

        // Nur alphanumerische Zeichen, 8 Stellen, Uppercase.
        // Vermeidet Base64-Sonderzeichen (+, /, =) die schlecht abtippbar sind.
        let displayCode = response.token
            .filter { $0.isLetter || $0.isNumber }
            .prefix(8)
            .uppercased()
        return String(displayCode)
    }

    // MARK: - Admin-Aktionen (via SECURITY DEFINER RPCs)

    /// T-3-06: remove_member RPC prueft Admin-Count; wirft lastAdminProtection wenn letzter Admin.
    func removeMember(memberId: UUID) async throws {
        struct Params: Encodable {
            let targetMemberId: UUID
            enum CodingKeys: String, CodingKey { case targetMemberId = "target_member_id" }
        }
        do {
            try await supabase
                .rpc("remove_member", params: Params(targetMemberId: memberId))
                .execute()
        } catch {
            let msg = error.localizedDescription.lowercased()
            if msg.contains("keine admin") || msg.contains("berechtigung") || msg.contains("not admin") {
                throw FamilyServiceError.insufficientPermissions
            }
            if msg.contains("mindestens einen admin") || msg.contains("last admin") {
                throw FamilyServiceError.lastAdminProtection
            }
            throw FamilyServiceError.unknown(error.localizedDescription)
        }
    }

    /// T-3-01: changeMemberRole ruft ausschliesslich change_member_role RPC auf (SECURITY DEFINER + Admin-Check).
    func changeMemberRole(memberId: UUID, role: MemberRole) async throws {
        struct Params: Encodable {
            let targetMemberId: UUID
            let newRole: String
            enum CodingKeys: String, CodingKey {
                case targetMemberId = "target_member_id"
                case newRole = "new_role"
            }
        }
        do {
            try await supabase
                .rpc("change_member_role", params: Params(targetMemberId: memberId, newRole: role.rawValue))
                .execute()
        } catch {
            let msg = error.localizedDescription.lowercased()
            if msg.contains("keine admin") || msg.contains("berechtigung") || msg.contains("not admin") {
                throw FamilyServiceError.insufficientPermissions
            }
            if msg.contains("mindestens einen admin") || msg.contains("last admin") {
                throw FamilyServiceError.lastAdminProtection
            }
            throw FamilyServiceError.unknown(error.localizedDescription)
        }
    }

    // MARK: - Eigenes Profil bearbeiten (direktes REST -- kein RPC noetig)

    /// T-3-01: Direktes UPDATE ist sicher weil die RLS-Policy nur display_name + avatar_color zulaesst.
    /// role + family_id koennen NICHT ueber diesen Pfad veraendert werden (Policy-Design).
    func updateProfile(displayName: String, avatarColor: String) async throws {
        struct ProfileUpdate: Encodable {
            let display_name: String
            let avatar_color: String
            let updated_at: Date
        }
        let currentUserId: UUID
        do {
            currentUserId = try await supabase.auth.session.user.id
        } catch {
            throw FamilyServiceError.notAuthenticated
        }

        try await supabase
            .from("family_members")
            .update(ProfileUpdate(
                display_name: displayName,
                avatar_color: avatarColor,
                updated_at: Date()
            ))
            .eq("id", value: currentUserId.uuidString)
            .execute()
    }

    // MARK: - Kinder-Profile

    /// T-3-05: RLS Policy "Admin erstellt Kind-Profile" WITH CHECK blockiert serverseitig.
    /// Kein client-seitiger Admin-Check -- Admin-Pruefung ausschliesslich via RLS.
    func createChildProfile(name: String, avatarColor: String) async throws -> UUID {
        struct NewChildProfile: Encodable {
            let family_id: String
            let display_name: String
            let avatar_color: String
            let created_by: String
        }
        struct ProfileResponse: Decodable { let id: UUID }

        guard let familyId = currentFamily?.id else {
            throw FamilyServiceError.familyNotFound
        }
        let currentUserId: UUID
        do {
            currentUserId = try await supabase.auth.session.user.id
        } catch {
            throw FamilyServiceError.notAuthenticated
        }

        let response: ProfileResponse = try await supabase
            .from("child_profiles")
            .insert(NewChildProfile(
                family_id: familyId.uuidString,
                display_name: name,
                avatar_color: avatarColor,
                created_by: currentUserId.uuidString
            ))
            .select("id")
            .single()
            .execute()
            .value

        // Nach Erstellen die Liste neu laden
        await fetchChildProfiles(familyId: familyId)
        return response.id
    }
}

// MARK: - Error-Enum

enum FamilyServiceError: Error, LocalizedError {
    case notAuthenticated
    case familyNotFound
    case invalidToken
    case alreadyInFamily
    case insufficientPermissions
    case lastAdminProtection
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:        return "Bitte zuerst einloggen."
        case .familyNotFound:          return "Familie nicht gefunden."
        case .invalidToken:            return "Ungültiger oder abgelaufener Einladungscode."
        case .alreadyInFamily:         return "Du bist bereits Mitglied einer Familie."
        case .insufficientPermissions: return "Keine Berechtigung für diese Aktion."
        case .lastAdminProtection:     return "Die Familie muss mindestens einen Admin haben."
        case .unknown(let msg):        return msg
        }
    }
}
