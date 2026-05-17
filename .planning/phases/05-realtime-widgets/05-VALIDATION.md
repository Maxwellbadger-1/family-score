---
phase: 5
slug: realtime-widgets
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-17
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (FamilyScoreTests-Target aus Phase 2 vorhanden) |
| **Config file** | Xcode-Projekt (FamilyScore.xcodeproj) |
| **Quick run command** | `xcodebuild build -scheme FamilyScore -destination "generic/platform=iOS Simulator" -quiet` |
| **Full suite command** | `xcodebuild test -scheme FamilyScore -destination "platform=iOS Simulator,OS=17.5,name=iPhone 16"` |
| **Estimated runtime** | ~90 seconds (Build + Unit Tests) |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild build -scheme FamilyScore -destination "generic/platform=iOS Simulator" -quiet`
- **After every plan wave:** Run full test suite (`xcodebuild test ...`)
- **Before `/gsd-verify-work`:** Full suite grün + Gerät-Checkpoint (Sideloadly) für App Group, Widget-Rendering, Deep Links
- **Max feedback latency:** ~90 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 5-01-01 | 01 | 0 | SYNC-01 | — | XCTestConfigurationFilePath-Guard verhindert Realtime-Connect in CI | Unit | `xcodebuild test ... -only-testing:FamilyScoreTests/RealtimeServiceTests` | ❌ W0 | ⬜ pending |
| 5-01-02 | 01 | 0 | SYNC-01/02 | — | MockRealtimeService konformiert RealtimeServiceProtocol | Unit | `xcodebuild test ...` | ❌ W0 | ⬜ pending |
| 5-01-03 | 01 | 0 | WIDGET-01..05 | — | WidgetDataWriter.write() schreibt korrekte JSON-Daten in App Group | Unit | `xcodebuild test ... -only-testing:FamilyScoreTests/WidgetDataWriterTests` | ❌ W0 | ⬜ pending |
| 5-01-04 | 01 | 0 | WIDGET-04 | — | LogActivityIntent.perform() schreibt pendingLogs in App Group | Unit | `xcodebuild test ... -only-testing:FamilyScoreTests/LogActivityIntentTests` | ❌ W0 | ⬜ pending |
| 5-02-01 | 02 | 1 | SYNC-01 | — | RealtimeService.startListening() subscribed Channel mit korrekter familyId | Unit | `xcodebuild test ...` | ❌ W0 | ⬜ pending |
| 5-02-02 | 02 | 1 | SYNC-01 | — | scenePhase .active ruft refetchAndResubscribe() auf | Unit | `xcodebuild test ...` | ❌ W0 | ⬜ pending |
| 5-02-03 | 02 | 1 | SYNC-02 | — | INSERT-Change aktualisiert ActivityService.entries | Unit | `xcodebuild test ...` | ❌ W0 | ⬜ pending |
| 5-02-04 | 02 | 1 | SYNC-02 | — | WidgetDataWriter.updateAndReload() nach Realtime-Event aufgerufen | Unit | `xcodebuild test ...` | ❌ W0 | ⬜ pending |
| 5-03-01 | 03 | 1 | WIDGET-03 | — | FamilyRankingView sortiert Members nach weeklyPoints absteigend | Unit | `xcodebuild test ... -only-testing:FamilyScoreTests/WidgetViewTests` | ❌ W0 | ⬜ pending |
| 5-03-02 | 03 | 1 | WIDGET-05 | — | PersonalRingsView zeigt korrekte Progress-Werte aus WidgetData | Unit | `xcodebuild test ...` | ❌ W0 | ⬜ pending |
| 5-03-03 | 03 | 1 | WIDGET-04 | — | iOS 16 Fallback: #available(iOS 17, *) zeigt Deep-Link-View | Unit | `xcodebuild test ...` | ❌ W0 | ⬜ pending |
| 5-04-01 | 04 | 3 | SYNC-03 | T-5-APNs | APNs-Token wird via upsert in device_push_tokens gespeichert | Integration (Gerät) | Gerät-Checkpoint | N/A | ⬜ pending |
| 5-04-02 | 04 | 3 | SYNC-03 | T-5-EdgeFn | Edge Function sendet Push an andere Familienmitglieder | Manuell (2 Geräte) | Gerät-Checkpoint | N/A | ⬜ pending |
| 5-XX-01 | — | — | WIDGET-01 | — | accessoryCircular rendert korrekt auf Lock Screen (kein Crash) | Manuell (Gerät) | Sideloadly → Lock Screen | N/A | ⬜ pending |
| 5-XX-02 | — | — | WIDGET-02 | — | Deep Link familyscore://log?category=haushalt öffnet ActivityLogSheet | Manuell (Gerät) | Sideloadly → Widget → tippen | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `FamilyScoreTests/RealtimeServiceTests.swift` — Unit-Test-Stubs für SYNC-01/02 (Mock-Channel)
- [ ] `FamilyScoreTests/Mocks/MockRealtimeService.swift` — RealtimeServiceProtocol + MockRealtimeService
- [ ] `FamilyScoreTests/WidgetDataWriterTests.swift` — App Group schreiben/lesen, reloadAllTimelines() Mock
- [ ] `FamilyScoreTests/LogActivityIntentTests.swift` — LogActivityIntent.perform() schreibt pendingLogs
- [ ] `FamilyScoreTests/WidgetViewTests.swift` — FamilyRankingView sortedMembers, PersonalRingsView Progress-Werte

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| App Group funktioniert auf physischem Gerät | SC-2 (Phase 1 offen) | Simulator ignoriert Portal-Entitlements; App Group muss auf Gerät verifiziert werden | Sideloadly → `.ipa` installieren → App öffnen → verifyAppGroup() Debug-Log prüfen |
| Lock Screen accessoryCircular Widget rendert | WIDGET-01 | Widget-Rendering auf Lock Screen nur auf Gerät testbar | Sideloadly → Widget zu Lock Screen hinzufügen → Score-Ring prüfen |
| accessoryRectangular Deep Link öffnet App | WIDGET-02 | Deep Link aus Lock Screen Widget nur auf Gerät vollständig testbar | Sideloadly → Lock Screen Widget → Haushalt tippen → ActivityLogSheet erscheint |
| Push-Benachrichtigung wird empfangen | SYNC-03 | APNs erfordert physische Geräte mit echten APNs-Token | Zwei Geräte mit Sideloadly → Aktivität auf Gerät A → Push auf Gerät B erscheint |
| Familien-Score-Update live via Realtime | SYNC-01 | Zwei-Geräte-Szenario nicht automatisierbar | Gerät A loggt Aktivität → Gerät B prüft ob Rings und Feed aktualisiert sind |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
