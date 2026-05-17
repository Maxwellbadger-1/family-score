// FamilyScore/Models/ChildProfile.swift
// Target Membership: FamilyScore (App) ONLY

import Foundation

struct ChildProfile: Codable, Identifiable {
    let id: UUID
    let family_id: UUID
    let display_name: String
    let avatar_color: String
    let created_by: UUID
    let created_at: Date
}
