---
phase: "03"
plan: "01"
subsystem: family-core
tags: [sql-migration, rls, rpc, models, test-infrastructure, wave-0]
dependency_graph:
  requires:
    - "02-01 (AuthService, AppState, FamilyScoreTests-Target vorhanden)"
    - "01-01 (Initial Schema: families, family_members, category_config, family_invites)"
  provides:
    - "supabase/migrations/20260515_phase3_family_core.sql (push-bereit fuer Plan 02)"
    - "FamilyServiceProtocol (contract fuer Wave 1 FamilyService)"
    - "MockFamilyService (einsatzbereit fuer Unit-Tests)"
    - "5 Model-Structs: Family, FamilyMember, ChildProfile, FamilyInvite, MemberRole"
    - "10 Teststubs fuer FAM-01..KID-01"
  affects:
    - "03-02 (kann FamilyService gegen FamilyServiceProtocol implementieren)"
    - "03-03 (Views koennen Models importieren)"
tech_stack:
  added: []
  patterns:
    - "SECURITY DEFINER RPCs fuer alle Multi-Tabellen-Operationen"
    - "ObservableObject + @Published (iOS 16 Minimum; kein @Observable)"
    - "MockService-Muster mit shouldThrow-Flags + CallCount-Properties"
    - "SQL-Migrationen als eigenstaendige Dateien (push in Plan 02)"
key_files:
  created:
    - "FamilyScore/supabase/migrations/20260515_phase3_family_core.sql"
    - "FamilyScore/FamilyScore/Models/Family.swift"
    - "FamilyScore/FamilyScore/Models/FamilyMember.swift"
    - "FamilyScore/FamilyScore/Models/ChildProfile.swift"
    - "FamilyScore/FamilyScore/Models/FamilyInvite.swift"
    - "FamilyScore/FamilyScore/Models/MemberRole.swift"
    - "FamilyScore/FamilyScoreTests/Mocks/MockFamilyService.swift"
    - "FamilyScore/FamilyScoreTests/FamilyServiceTests.swift"
  modified: []
decisions:
  - "FamilyServiceProtocol im Test-Target definiert (nicht im App-Target) — gleiche Entscheidung wie AuthServiceProtocol in Phase 2 Wave 0"
  - "MemberRole als eigenstaendige Datei (nicht in FamilyService.swift inline) — fuer saubere Imports in Tests und Views"
  - "child_profiles DDL enthaelt display_name BETWEEN 1 AND 50 Constraint (Pitfall-Praevention; Supabase rejiziert leere Namen serverseitig)"
  - "SQL-Migration noch NICHT zur Datenbank gepusht — das ist Plan 02 Aufgabe (Supabase CLI push)"
metrics:
  duration: "5 Minuten"
  completed_date: "2026-05-17"
  tasks_completed: 2
  tasks_total: 2
  files_created: 8
  files_modified: 0
---

# Phase 3 Plan 01: Wave 0 Foundation — SQL-Migration + Test-Infrastruktur

**One-liner:** SECURITY DEFINER RPCs (create_family, accept_invite, change_member_role, remove_member) plus child_profiles DDL als push-bereite SQL-Migration; FamilyServiceProtocol + MockFamilyService + 10 XCTest-Stubs als Wave-0-Testgrundlage.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | SQL-Migration Phase 3 | 1b290d2 | FamilyScore/supabase/migrations/20260515_phase3_family_core.sql |
| 2 | FamilyService-Test-Infrastruktur | 78b4e4a | Models/*.swift, FamilyScoreTests/Mocks/MockFamilyService.swift, FamilyScoreTests/FamilyServiceTests.swift |

## Deliverables

### SQL-Migration: `20260515_phase3_family_core.sql`

**Abschnitt 1 — child_profiles-Tabelle:**
- DDL mit `display_name CHECK (BETWEEN 1 AND 50)`, `avatar_color DEFAULT '#FF9500'`
- Index `child_profiles_family_id` (Pitfall 6 vermieden)
- RLS: SELECT fuer Familienmitglieder; INSERT/ALL fuer Admins (T-3-05 mitigiert)

**Abschnitt 2 — family_members UPDATE-Policy Migration:**
- `drop policy if exists "User verwaltet eigenes Profil"` (Phase-1-Policy entfernt)
- Neue Policy: `using ((select auth.uid()) = id) with check ((select auth.uid()) = id)` — sicher fuer display_name/avatar_color; role/family_id nur via SECURITY DEFINER RPCs aenderbar (T-3-01 mitigiert)

**Abschnitt 3 — 4 SECURITY DEFINER RPCs:**

| RPC | Sicherheitschecks | set search_path |
|-----|-------------------|-----------------|
| create_family(family_name) | Laengenvalidierung + User-ohne-Familie-Check + category_config-Seeding | Ja |
| accept_invite(invite_token) | User-ohne-Familie-Check + used_by IS NULL + expires_at > now() (T-3-02) | Ja |
| change_member_role(target, new_role) | Rollenvalidierung + is_family_admin() + letzter-Admin-Schutz (T-3-06) | Ja |
| remove_member(target) | is_family_admin() + letzter-Admin-Schutz (T-3-06) | Ja |

### Model-Structs (5 Dateien)

| Datei | Typ | Besonderheit |
|-------|-----|-------------|
| Family.swift | Codable, Identifiable | snake_case = DB-Spaltennamen; created_by nullable |
| FamilyMember.swift | Codable, Identifiable | role als String (robust bei unbekannten DB-Werten) |
| ChildProfile.swift | Codable, Identifiable | family_id non-null; created_by = auth.users-FK |
| FamilyInvite.swift | Codable, Identifiable | used_by/used_at nullable; expires_at non-null |
| MemberRole.swift | String, Codable, CaseIterable | displayName computed (Deutsch) |

### FamilyServiceProtocol + MockFamilyService

**Protocol definiert 10 Methoden** (createFamily, joinFamily, fetchFamily, fetchMembers, fetchChildProfiles, generateInvite, removeMember, changeMemberRole, updateProfile, createChildProfile)

**MockFamilyService-Eigenschaften:**
- `shouldThrow*` Flags fuer 5 Methoden
- `*CallCount` Properties fuer 8 Methoden
- `last*` Properties fuer 4 Parameter-Assertions
- `set*` Testhelfer-Methoden (setCurrentFamily, setMembers, setChildProfiles)

### FamilyServiceTests (10 Teststubs)

| Test | Requirement |
|------|-------------|
| testCreateFamilySetsCurrentFamily | FAM-01 |
| testCreateFamilyThrowsWhenAlreadyInFamily | FAM-01 |
| testGenerateInviteReturnsCode | FAM-02 |
| testJoinFamilyWithValidTokenSetsFamily | FAM-02 |
| testJoinFamilyWithInvalidTokenThrows | FAM-02 |
| testRemoveMemberRemovesMemberFromList | FAM-03 |
| testRemoveMemberThrowsWithoutAdminPermission | FAM-03 |
| testChangeMemberRoleUpdatesRole | FAM-04 |
| testChangeMemberRoleThrowsWithoutAdminPermission | FAM-04 |
| testCreateChildProfileAddsToChildProfiles | KID-01 |
| testUpdateProfileCallsService | FAM-05 |

## Deviations from Plan

None — Plan wurde exakt wie geschrieben ausgefuehrt.

## Known Stubs

Die `FamilyServiceTests.swift`-Tests sind bewusste Stubs (per Plan). Sie testen MockFamilyService, nicht den echten FamilyService (der noch nicht existiert). Wave 1 (Plan 02) implementiert `FamilyService.swift` gegen `FamilyServiceProtocol` — danach decken die gleichen Tests reale Supabase-Aufrufe ab.

Die Stubs verhindern das Plan-Ziel NICHT: Wave 0 zielt explizit auf kompilierbare Teststubs, nicht auf gruene Integrations-Tests.

## Build Status

Lokales Build auf Windows nicht moeglich (kein Xcode). CI (GitHub Actions) baut nach Push via `xcodegen generate` + `xcodebuild`. Die Files sind korrekt strukturiert:
- Keine Namenskonflikte mit bestehenden Typen verifiziert (grep auf gesamtes Projekt)
- XcodeGen source paths decken neue Verzeichnisse automatisch ab (path: FamilyScore, path: FamilyScoreTests)
- Kein @Observable verwendet (iOS 16 Minimum eingehalten)

## Self-Check: PASSED

- SQL-Migration vorhanden: FOUND
- Models vorhanden: FOUND (5 Dateien)
- MockFamilyService vorhanden: FOUND
- FamilyServiceTests vorhanden: FOUND
- Commits 1b290d2 und 78b4e4a: FOUND
