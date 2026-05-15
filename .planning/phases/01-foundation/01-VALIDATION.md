---
phase: 1
slug: foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-15
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Kein XCTest-Target in Phase 1 (wird in Phase 2 eingerichtet). Build + Shell-Checks |
| **Config file** | none — manuelle Verifikation + Shell-Befehle |
| **Quick run command** | `xcodebuild -project FamilyScore.xcodeproj -scheme FamilyScore -destination "generic/platform=iOS" build` |
| **Full suite command** | Alle 5 Success Criteria manuell (SC-1 bis SC-5) |
| **Estimated runtime** | ~3 Minuten Build + ~10 Minuten manuelle Device-Verifikation |

---

## Sampling Rate

- **Nach jedem Task-Commit:** Run `xcodebuild ... build` (SC-1 Build)
- **Nach jedem Plan-Wave:** Run Full Suite (SC-4 secrets check + Build)
- **Vor `/gsd-verify-work`:** Alle 5 SC manuell abgehakt
- **Max feedback latency:** ~180 Sekunden (Build)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|--------|
| 1-01-SC1 | 01 | 1 | SC-1 (Build) | — | Keine Secrets im Build | build | `xcodebuild ... build` → BUILD SUCCEEDED | ⬜ pending |
| 1-01-SC2 | 01 | 2 | SC-2 (App Group) | — | App Group Container isoliert per Entitlement | manual | UserDefaults(suiteName:) write+read auf echtem Gerät → PASS | ⬜ pending |
| 1-02-SC3 | 02 | 2 | SC-3 (Supabase RLS) | — | Unauthentifizierte Abfrage gibt [] zurück (RLS aktiv) | integration | Swift-Debug-Code: supabase.from("families").select().execute() → 0 rows | ⬜ pending |
| 1-02-SC4 | 02 | 1 | SC-4 (Secrets) | T-1-01 | Anon Key nicht in Git | automated | `git grep -r "supabase.co" -- "*.swift" "*.json" "*.plist"` → 0 Treffer | ⬜ pending |
| 1-03-SC5 | 03 | 1 | SC-5 (FamilyScoreKit) | — | Widget Extension hat keinen direkten Supabase-Import | build | `xcodebuild ... build` + Xcode Build Phases prüfen | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Phase 1 hat kein dediziertes Test-Target (wird in Phase 2 hinzugefügt). Folgende Debug-Stubs sind direkt im App-Code (`#if DEBUG`):

- [ ] `FamilyScore/Debug/Phase1Verification.swift` — SC-2 App Group + SC-3 Supabase Debug-Code
- [ ] Inhalt: `verifyAppGroup()` + `verifySupabaseConnection()` — beide aus RESEARCH.md Validation Architecture kopieren

*Nach Phase 1 werden diese Debug-Funktionen entfernt.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| App Group bidirektional auf Gerät | SC-2 | Simulator zeigt falsch-positiv; nur echtes Gerät mit Portal-Entitlement beweist Korrektheit | 1. App starten → SC-2 Debug-Code loggt "App Group Test: PASS ✓". 2. Widget-Timeline triggern → loggt "read from Widget: PASS ✓". Beide müssen PASS zeigen. |
| Widget Extension startet ohne Crash | SC-1 | Xcode Build ≠ Runtime-Verhalten auf Gerät | Gerät: Langer Druck auf Home Screen → Widget hinzufügen → FamilyScore-Widget erscheint ohne Crash |
| Supabase Dashboard zeigt RLS aktiviert | SC-3 (zusätzlich) | UI-Verifizierung neben dem Swift-Test | Supabase Dashboard → Table Editor → jede Tabelle → RLS-Badge = grün |

---

## Validation Sign-Off

- [ ] Alle Tasks haben `<automated>` verify oder Wave 0 Dependencies
- [ ] Sampling continuity: kein Build nach Task-Commit ausgelassen
- [ ] SC-4 (Secrets) per `git grep` vor jedem Commit verifiziert
- [ ] Keine watch-mode Flags
- [ ] Feedback latency < 180s (Build)
- [ ] SC-2 auf echtem physischen iOS-Gerät verifiziert (nicht nur Simulator)
- [ ] `nyquist_compliant: true` gesetzt wenn alle Checks grün

**Approval:** pending
