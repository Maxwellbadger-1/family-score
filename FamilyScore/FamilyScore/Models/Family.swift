// FamilyScore/Models/Family.swift
// Target Membership: FamilyScore (App) ONLY
// snake_case Property-Namen = DB-Spaltennamen (kein CodingKeys noetig fuer Supabase-Decoding)

import Foundation

struct Family: Codable, Identifiable {
    let id: UUID
    let name: String
    let created_at: Date
    let created_by: UUID?
}
