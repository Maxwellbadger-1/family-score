// FamilyScore/Views/Family/RolePickerSheet.swift
// Target Membership: FamilyScore (App) ONLY

import SwiftUI

struct RolePickerSheet: View {
    let member: FamilyMember
    @EnvironmentObject private var familyService: FamilyService
    @Environment(\.dismiss) private var dismiss

    @State private var selectedRole: MemberRole
    @State private var isLoading: Bool = false

    init(member: FamilyMember) {
        self.member = member
        _selectedRole = State(initialValue: MemberRole(rawValue: member.role) ?? .adult)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 32) {
                // Header
                HStack {
                    Button("Abbrechen") { dismiss() }
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Rolle aendern")
                        .font(.headline).foregroundColor(.white)
                    Spacer()
                    Button {
                        Task { await confirmRoleChange() }
                    } label: {
                        if isLoading { ProgressView().scaleEffect(0.8) }
                        else { Text("Bestaetigen").bold() }
                    }
                    .foregroundColor(.white)
                    .disabled(isLoading || MemberRole(rawValue: member.role) == selectedRole)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                // Mitglied-Info
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color(hex: member.avatar_color) ?? .blue)
                        .frame(width: 52, height: 52)
                        .overlay {
                            Text(String(member.display_name.prefix(1)).uppercased())
                                .font(.title3.bold()).foregroundColor(.white)
                        }
                    Text(member.display_name)
                        .font(.title3.bold()).foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 24)

                // Rollen-Picker
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(MemberRole.allCases, id: \.self) { role in
                        Button {
                            selectedRole = role
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(role.displayName)
                                        .font(.body).foregroundColor(.white)
                                    Text(roleDescription(role))
                                        .font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                if selectedRole == role {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(16)
                            .background(
                                selectedRole == role
                                    ? Color.white.opacity(0.15)
                                    : Color.white.opacity(0.05)
                            )
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
    }

    private func roleDescription(_ role: MemberRole) -> String {
        switch role {
        case .admin:  return "Kann Mitglieder einladen, entfernen und Rollen aendern"
        case .adult:  return "Kann Aktivitaeten loggen und Familie sehen"
        case .child:  return "Vereinfachte UI, nur eigene Daten sichtbar"
        }
    }

    private func confirmRoleChange() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await familyService.changeMemberRole(memberId: member.id, role: selectedRole)
            // Mitgliederliste aktualisieren
            if let familyId = familyService.currentFamily?.id {
                await familyService.fetchMembers(familyId: familyId)
            }
            dismiss()
        } catch {
            familyService.serviceError = error.localizedDescription
        }
    }
}
