---
phase: 3
slug: family-core
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-15
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (FamilyScoreTests-Target aus Phase 2 Wave 0) |
| **Config file** | `FamilyScore.xcodeproj` → Test-Target `FamilyScoreTests` (bereits vorhanden) |
| **Quick run command** | `xcodebuild build -scheme FamilyScore -destination "platform=iOS Simulator,name=iPhone 16" -quiet` |
| **Full suite command** | `xcodebuild test -scheme FamilyScore -destination "platform=iOS Simulator,name=iPhone 16"` |
| **Estimated runtime** | ~120 seconds (full suite mit Simulator-Start) |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild build -scheme FamilyScore -destination "platform=iOS Simulator,name=iPhone 16" -quiet`
- **After every plan wave:** Run `xcodebuild test -scheme FamilyScore -destination "platform=iOS Simulator,name=iPhone 16"`
- **Before `/gsd-verify-work`:** Full suite must be green + Invite-Flow auf zwei echten Geräten manuell verifiziert
- **Max feedback latency:** ~15 seconds (Build), ~120 seconds (Test-Suite)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 3-W0-01 | Wave0 | 0 | FAM-01..KID-01 | — | N/A | unit stub | `xcodebuild build ...` | ❌ W0 | ⬜ pending |
| 3-01-01 | 01 | 1 | FAM-01 | T-3-01 | create_family RPC atomar; creator wird Admin | unit (Mock) | `xcodebuild test ...` | ❌ W0 | ⬜ pending |
| 3-01-02 | 01 | 1 | FAM-01 | T-3-07 | createFamily() während User schon Familie hat → Fehler | unit (Mock) | `xcodebuild test ...` | ❌ W0 | ⬜ pending |
| 3-02-01 | 02 | 1 | FAM-02 | T-3-02 | accept_invite prüft used_by is null (single-use) | integration | `xcodebuild test ...` | ❌ W0 | ⬜ pending |
| 3-02-02 | 02 | 1 | FAM-02 | T-3-03 | joinFamily() mit abgelaufenem Token → Fehler | integration | `xcodebuild test ...` | ❌ W0 | ⬜ pending |
| 3-03-01 | 03 | 2 | FAM-03 | T-3-06 | remove_member prüft: min. 1 Admin verbleibt | integration | `xcodebuild test ...` | ❌ W0 | ⬜ pending |
| 3-03-02 | 03 | 2 | FAM-04 | T-3-01 | User kann eigene Rolle nicht direkt ändern (RLS WITH CHECK) | integration | `xcodebuild test ...` | ❌ W0 | ⬜ pending |
| 3-04-01 | 04 | 2 | KID-01 | T-3-05 | child_profiles INSERT nur von Admin erlaubt | integration | `xcodebuild test ...` | ❌ W0 | ⬜ pending |
| 3-05-01 | 05 | 2 | FAM-05 | — | updateProfile() ändert display_name + avatar_color | integration | `xcodebuild test ...` | ❌ W0 | ⬜ pending |
| 3-UI-01 | UI | 3 | SETTINGS-03 | — | Admin sieht "Mitglied entfernen"-Option; Nicht-Admin nicht | manual | — | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `FamilyScoreTests/FamilyServiceTests.swift` — Unit + Integration Test-Stubs für FAM-01 bis KID-01
- [ ] `FamilyScoreTests/Mocks/MockFamilyService.swift` — Mock-Implementierung für FamilyServiceProtocol

*(FamilyScoreTests-Target selbst ist bereits aus Phase 2 Wave 0 vorhanden)*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Invite-Flow zwischen zwei echten Geräten | FAM-02 | Erfordert 2 physische Devices + 2 Accounts | Admin generiert Code auf Gerät A; zweiter User gibt Code auf Gerät B ein; beide sehen dieselbe Familie |
| Admin-Only UI-Elemente sichtbar/verborgen | SETTINGS-03 | UI-State hängt von AppState.currentMember.role ab | Als Admin: "Mitglied entfernen" + "Rolle ändern" sichtbar. Als Adult: beide Buttons fehlen |
| Kind-Profil erscheint in Mitgliederliste | KID-01 | Parent-managed, kein eigenes Gerät nötig | Admin erstellt Kind-Profil; Kind erscheint in MemberListView ohne Login-Anforderung |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s (build < 15s, full suite < 120s)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
