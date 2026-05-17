// FamilyScore/Models/FamilyInvite.swift
// Target Membership: FamilyScore (App) ONLY

import Foundation

struct FamilyInvite: Codable, Identifiable {
    let id: UUID
    let family_id: UUID
    let token: String
    let expires_at: Date
    let used_by: UUID?
    let used_at: Date?
    let created_at: Date
}
