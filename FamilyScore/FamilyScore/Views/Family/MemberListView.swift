// FamilyScore/Views/Family/MemberListView.swift
// Target Membership: FamilyScore (App) ONLY

import SwiftUI

struct MemberListView: View {
    @EnvironmentObject private var familyService: FamilyService
    @State private var showInviteSheet: Bool = false
    @State private var showAddChild: Bool = false
    @State private var selectedMemberForRole: FamilyMember? = nil

    // Prueft ob irgendjemand Admin ist (fuer UI-Sichtbarkeit)
    // SICHERHEITSHINWEIS: Nur fuer UI; Admin-Check auf Server via SECURITY DEFINER RPCs
    // TODO(Phase 4): echten currentUser.id Vergleich einbauen
    private var currentUserIsAdmin: Bool {
        familyService.members.contains { $0.role == "admin" }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            List {
                // Echte Mitglieder
                if !familyService.members.isEmpty {
                    Section {
                        ForEach(familyService.members) { member in
                            MemberRow(member: member, isAdmin: currentUserIsAdmin)
                                .listRowBackground(Color.white.opacity(0.05))
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if currentUserIsAdmin && member.role != "admin" {
                                        Button(role: .destructive) {
                                            Task {
                                                do {
                                                    try await familyService.removeMember(memberId: member.id)
                                                    if let familyId = familyService.currentFamily?.id {
                                                        await familyService.fetchMembers(familyId: familyId)
                                                    }
                                                } catch {
                                                    familyService.serviceError = error.localizedDescription
                                                }
                                            }
                                        } label: {
                                            Label("Entfernen", systemImage: "person.badge.minus")
                                        }
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    if currentUserIsAdmin {
                                        Button {
                                            selectedMemberForRole = member
                                        } label: {
                                            Label("Rolle", systemImage: "person.badge.shield.checkmark")
                                        }
                                        .tint(.blue)
                                    }
                                }
                        }
                    } header: {
                        Text("Mitglieder")
                            .foregroundColor(.secondary)
                            .font(.caption)
                            .textCase(nil)
                    }
                }

                // Kind-Profile
                if !familyService.childProfiles.isEmpty {
                    Section {
                        ForEach(familyService.childProfiles) { child in
                            ChildProfileRow(child: child)
                                .listRowBackground(Color.white.opacity(0.05))
                        }
                    } header: {
                        Text("Kinder")
                            .foregroundColor(.secondary)
                            .font(.caption)
                            .textCase(nil)
                    }
                }
            }
            .listStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Familie")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if currentUserIsAdmin {
                    Menu {
                        Button("Einladungscode generieren") { showInviteSheet = true }
                        Button("Kind-Profil hinzufuegen") { showAddChild = true }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showInviteSheet) {
            InviteSheet()
                .environmentObject(familyService)
        }
        .sheet(isPresented: $showAddChild) {
            AddChildView()
                .environmentObject(familyService)
        }
        .sheet(item: $selectedMemberForRole) { member in
            RolePickerSheet(member: member)
                .environmentObject(familyService)
        }
        .task {
            if let familyId = familyService.currentFamily?.id {
                await familyService.fetchMembers(familyId: familyId)
                await familyService.fetchChildProfiles(familyId: familyId)
            }
        }
        .overlay {
            if let error = familyService.serviceError {
                VStack {
                    Spacer()
                    HStack {
                        Text(error).font(.subheadline).foregroundColor(.white)
                        Spacer()
                        Button { familyService.serviceError = nil } label: {
                            Image(systemName: "xmark").foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(Color.red.opacity(0.85))
                    .cornerRadius(12)
                    .padding()
                }
            }
        }
    }
}

// MARK: - Sub-Views

struct MemberRow: View {
    let member: FamilyMember
    let isAdmin: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Avatar-Kreis
            Circle()
                .fill(Color(hex: member.avatar_color) ?? .blue)
                .frame(width: 44, height: 44)
                .overlay {
                    Text(String(member.display_name.prefix(1)).uppercased())
                        .font(.headline)
                        .foregroundColor(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(member.display_name)
                    .foregroundColor(.white)
                    .font(.body)
                HStack(spacing: 4) {
                    if member.role == "admin" {
                        Image(systemName: "crown.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                    }
                    Text(MemberRole(rawValue: member.role)?.displayName ?? member.role)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct ChildProfileRow: View {
    let child: ChildProfile

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: child.avatar_color) ?? .orange)
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "figure.child")
                        .font(.body)
                        .foregroundColor(.white)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(child.display_name)
                    .foregroundColor(.white)
                    .font(.body)
                Text("Kind-Profil (kein Login noetig)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Color Hex Extension

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6,
              let r = UInt8(hex.prefix(2), radix: 16),
              let g = UInt8(hex.dropFirst(2).prefix(2), radix: 16),
              let b = UInt8(hex.dropFirst(4), radix: 16)
        else { return nil }
        self.init(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}

#Preview {
    NavigationStack {
        MemberListView()
            .environmentObject(FamilyService())
    }
}
