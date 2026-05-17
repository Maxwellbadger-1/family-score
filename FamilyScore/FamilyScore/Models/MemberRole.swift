// FamilyScore/Models/MemberRole.swift
// Target Membership: FamilyScore (App) ONLY
// iOS 16.0 Minimum

import Foundation

enum MemberRole: String, Codable, CaseIterable {
    case admin
    case adult
    case child

    var displayName: String {
        switch self {
        case .admin:  return "Admin"
        case .adult:  return "Erwachsen"
        case .child:  return "Kind-vereinfacht"
        }
    }
}
