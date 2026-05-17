// FamilyScore/Models/FamilyMember.swift
// Target Membership: FamilyScore (App) ONLY

import Foundation

struct FamilyMember: Codable, Identifiable {
    let id: UUID
    let family_id: UUID?
    let display_name: String
    let avatar_color: String
    let role: String          // String statt MemberRole: robuster bei unbekannten DB-Werten
    let created_at: Date
}
