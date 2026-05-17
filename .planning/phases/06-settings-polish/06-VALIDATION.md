---
phase: 6
slug: settings-polish
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-17
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (bestehend seit Phase 2) |
| **Config file** | `project.yml` (FamilyScoreTests-Target) |
| **Quick run command** | `xcodebuild test-without-building -scheme FamilyScore -destination 'id=<UDID>'` |
| **Full suite command** | CI via GitHub Actions: `gh run list --limit 1` nach `git push` |
| **Estimated runtime** | ~60 seconds (Unit Tests, ohne Appetize.io) |

---

## Sampling Rate

- **After every task commit:** Unit Tests via CI (`git push` → `gh run list`)
- **After every plan wave:** Full Suite grün in CI
- **Before `/gsd-verify-work`:** CI grün + Appetize.io-Checkpoint: Kind-UI-Modus sichtbar, Settings-Toggles funktional
- **Max feedback latency:** ~60 seconds (Unit Tests)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 6-01-01 | 01 | 0 | SETTINGS-01/02 | T-6-01 | `toggleCategory()` nur für Admin (RLS) | unit | `xcodebuild test ... -only-testing:FamilyScoreTests/CategoryServiceTests` | ❌ W0 | ⬜ pending |
| 6-01-02 | 01 | 0 | SETTINGS-01 | — | `enabledCategories` filtert deaktivierte korrekt | unit | `... /CategoryServiceTests/testEnabledFilter` | ❌ W0 | ⬜ pending |
| 6-01-03 | 01 | 0 | SETTINGS-02 | T-6-02 | `updateWeight()` ändert keine historischen Einträge | unit | `... /CategoryServiceTests/testWeightUpdate` | ❌ W0 | ⬜ pending |
| 6-02-01 | 02 | 1 | SETTINGS-01/02 | T-6-01 | Settings-Tab nur für Admin sichtbar | unit | `... /CategoryServiceTests` | ✅ W0 | ⬜ pending |
| 6-03-01 | 03 | 2 | KID-02 | T-6-03 | `KindDashboardView` zeigt keinen Familienvergleich | manual | Appetize.io (kind@example.com) | N/A | ⬜ pending |
| 6-03-02 | 03 | 2 | KID-03 | T-6-03 | Nach `changeMemberRole(.child)` → KindDashboardView | manual | Appetize.io | N/A | ⬜ pending |
| 6-04-01 | 04 | 3 | — | T-6-04 | Kein Supabase-Anon-Key im Binary | manual | `strings FamilyScore.app/FamilyScore \| grep supabase` | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `FamilyScoreTests/CategoryServiceTests.swift` — Stubs für SETTINGS-01, SETTINGS-02
- [ ] `FamilyScoreTests/Mocks/MockCategoryService.swift` — für Category-Unit-Tests
- [ ] `FamilyScore/Models/CategoryConfig.swift` — Decodable-Model für `category_config`-Tabelle

*Bestehende XCTest-Infrastruktur (FamilyScoreTests-Target, MockAuthService, MockFamilyService) wird wiederverwendet.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Kind-Dashboard zeigt nur eigene Daten, keine Familie | KID-02 | SwiftUI-View-Rendering, kein Unit-Test-Äquivalent | Appetize.io: Mit `role == .child` einloggen → prüfen dass FamilienTab fehlt |
| Admin ändert Mitglied-Modus → UI wechselt sofort | KID-03 | Erfordert zwei Sessions / Gerätestatus | Appetize.io: Admin ändert Rolle, User lädt App neu → prüfe KindDashboardView erscheint |
| App Store: Kein Secret im Binary | SC-5 | Binär-Inspektion nötig | `strings FamilyScore.app/FamilyScore \| grep -i supabase` in CI-Artifact |
| Privacy Manifest vorhanden und korrekt | SC-5 | Apple-Validation in Xcode / TestFlight | PrivacyInfo.xcprivacy in Main-App-Target; Xcode-Warnung fehlt nach Build |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s (Unit Tests via CI)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
