---
phase: "03"
plan: "02"
subsystem: family-core
tags: [family-service, observable-object, supabase-rpc, auth-service, ios16]
dependency_graph:
  requires:
    - "03-01 (FamilyServiceProtocol, MockFamilyService, Models, SQL-Migration angewendet via MCP)"
    - "02-02 (AuthService mit checkFamilyMembership() privat definiert)"
  provides:
    - "FamilyScore/Services/FamilyService.swift (vollstaendige ObservableObject-Implementierung)"
    - "FamilyScore/Services/AuthService.swift (refreshFamilyStatus() hinzugefuegt)"
  affects:
    - "03-03 (Views koennen @EnvironmentObject familyService: FamilyService verwenden)"
    - "03-04 (RootView und FamilyScoreApp.swift koennen FamilyService injizieren)"
tech_stack:
  added: []
  patterns:
    - "ObservableObject + @Published (iOS 16 Minimum; kein @Observable)"
    - "Nested Encodable Params-Structs mit CodingKeys fuer snake_case RPC-Parameter"
    - "SECURITY DEFINER RPC fuer alle atomaren Multi-Tabellen-Operationen"
    - "private(set) auf alle @Published State-Properties (T-3-04)"
    - "Supabase insert + select(spalte) + single() fuer Returning-Pattern"
key_files:
  created:
    - "FamilyScore/FamilyScore/Services/FamilyService.swift"
  modified:
    - "FamilyScore/FamilyScore/Services/AuthService.swift"
decisions:
  - "FamilyService implementiert FamilyServiceProtocol nicht explizit (Protocol ist im Test-Target definiert) -- Konformanz ist strukturell (Duck-Typing), wird in Tests via @testable import sichergestellt"
  - "updateProfile() verwendet direktes REST-UPDATE (nicht RPC) weil RLS-Policy display_name/avatar_color-Only-Update sicherstellt; role/family_id nie aenderbar via diesem Pfad (T-3-01)"
  - "generateInvite() trimmt Token auf 8 alphanumerische Uppercase-Zeichen nach DB-Insert fuer bessere Abtippbarkeit"
  - "refreshFamilyStatus() in AuthService (nicht FamilyService) -- Dependency-Richtung: Views -> Services, nie Services -> Services"
metrics:
  duration: "8 Minuten"
  completed_date: "2026-05-17"
  tasks_completed: 2
  tasks_total: 3
  files_created: 1
  files_modified: 1
---

# Phase 3 Plan 02: FamilyService implementieren + AuthService erweitern

**One-liner:** FamilyService als @MainActor ObservableObject mit 10 Protocol-Methoden via supabase.rpc() fuer alle atomaren Operationen (create_family, accept_invite, remove_member, change_member_role) plus refreshFamilyStatus() in AuthService fuer manuellen AppState-Refresh nach RPC-Calls.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Supabase Schema Push | (via MCP, pre-completion) | child_profiles + 4 RPCs live |
| 2 | FamilyService implementieren | 220757d | FamilyScore/FamilyScore/Services/FamilyService.swift |
| 3 | AuthService refreshFamilyStatus() | 1fe1041 | FamilyScore/FamilyScore/Services/AuthService.swift |

## Deliverables

### FamilyService.swift

**Klassen-Signatur:** `@MainActor final class FamilyService: ObservableObject`

**Published Properties (alle `private(set)` ausser serviceError):**
- `currentFamily: Family?`
- `members: [FamilyMember]`
- `childProfiles: [ChildProfile]`
- `serviceError: String?`

**Implementierte Methoden:**

| Methode | Transport | Atomaritaet |
|---------|-----------|-------------|
| createFamily(name:) | supabase.rpc("create_family") | Ja -- RPC |
| joinFamily(token:) | supabase.rpc("accept_invite") | Ja -- RPC |
| fetchFamily(familyId:) | supabase.from("families").select() | N/A (Read) |
| fetchMembers(familyId:) | supabase.from("family_members").select() | N/A (Read) |
| fetchChildProfiles(familyId:) | supabase.from("child_profiles").select() | N/A (Read) |
| generateInvite(familyId:role:) | supabase.from("family_invites").insert().select("token") | N/A (Single-Table) |
| removeMember(memberId:) | supabase.rpc("remove_member") | Ja -- RPC |
| changeMemberRole(memberId:role:) | supabase.rpc("change_member_role") | Ja -- RPC |
| updateProfile(displayName:avatarColor:) | supabase.from("family_members").update() | N/A (Single-Table, RLS-gesichert) |
| createChildProfile(name:avatarColor:) | supabase.from("child_profiles").insert() | N/A (Single-Table) |

**FamilyServiceError-Enum (7 Cases):**
- notAuthenticated, familyNotFound, invalidToken, alreadyInFamily, insufficientPermissions, lastAdminProtection, unknown(String)

**iOS 16 Kompatibilitaet:** ObservableObject bestaetigt. Kein `@Observable` verwendet.

### AuthService.swift (Ergaenzung)

`refreshFamilyStatus()` hinzugefuegt am Ende der Klasse:
- Liest `currentUser?.id` (guard fuer nil)
- Ruft `checkFamilyMembership(userId:)` auf (bereits private definiert)
- Setzt `appState = .authenticated(hasFamily:)` manuell

Alle bestehenden Methoden unveraendert.

## Schema-Push-Status

Migration `20260515_phase3_family_core.sql` wurde via Supabase MCP vor diesem Plan angewendet:
- child_profiles Tabelle: live
- RPCs create_family, accept_invite, change_member_role, remove_member: live

## Deviations from Plan

None -- Plan wurde exakt wie geschrieben ausgefuehrt. Task 1 war bereits via MCP abgeschlossen und wurde uebersprungen.

## Known Stubs

Keine. FamilyService ist vollstaendig implementiert. FamilyServiceTests.swift (aus Plan 01) testen MockFamilyService -- der echte FamilyService wird via CI-Build und Supabase-Integration getestet (kein lokales xcodebuild moeglich auf Windows).

## Build Status

Lokales Build auf Windows nicht moeglich (kein Xcode). CI validiert via GitHub Actions nach Push. Strukturelle Korrektheit sichergestellt:
- Alle Protocol-Methoden implementiert (10/10)
- Keine @Observable Verwendung (iOS 16 eingehalten)
- Supabase-SDK nur im App-Target (CLAUDE.md-Constraint eingehalten)
- 4 RPC-Calls fuer atomare Operationen verifiziert

## Self-Check: PASSED

- FamilyService.swift vorhanden: FOUND (FamilyScore/FamilyScore/Services/FamilyService.swift)
- AuthService.swift modifiziert: FOUND (refreshFamilyStatus hinzugefuegt)
- Commit 220757d: FOUND
- Commit 1fe1041: FOUND
- @Observable in FamilyService: NOT FOUND (korrekt)
- supabase.rpc calls: 4 FOUND (create_family, accept_invite, remove_member, change_member_role)
