# Phase 5: Real-time & Widgets — Research

**Recherchiert:** 2026-05-17
**Domain:** Supabase Realtime (Swift), WidgetKit, AppIntents, APNs Push Notifications
**Konfidenz:** HIGH (Kern-Stack, Widget-Architektur), MEDIUM (APNs/Widget-Push-Detail, AppIntents-Verhalten)

---

## Zusammenfassung

Phase 5 verbindet drei technisch unabhängige Systeme: Supabase Realtime für Live-Sync zwischen Geräten, WidgetKit für fünf Widget-Oberflächen und APNs für opt-in Push-Benachrichtigungen. Die Architektur-Entscheidungen dafür sind in Phase 1 bereits getroffen und in ARCHITECTURE.md dokumentiert: App Group `group.com.familyscore`, `WidgetData`-Struct in `FamilyScoreKit`, `WidgetCenter.shared.reloadAllTimelines()` nach jedem Realtime-Event.

**Kritischer offener Punkt aus STATE.md:** "WidgetKit APNs push for widget updates when main app is backgrounded needs a spike before full implementation." Dieser Punkt ist in dieser Research-Phase aufgelöst: WidgetKit-Push ist über `WidgetPushHandler` + `apns-push-type: widgets` möglich ab iOS 16, aber signifikant komplexer als die App-Group-Lösung und durch iOS-Budget-Limitierungen eingeschränkt. **Empfehlung: WidgetKit-Push als dediziertes Wave 3 "Stretch Goal" planen, kein Blocker für die Kern-Requirements.**

Die drei Realtime-Subscriptions (activity_entries INSERT/DELETE, weekly_summaries UPDATE, profiles UPDATE) werden in einem einzelnen `RealtimeService`-Channel gebündelt — ein Channel pro Familien-ID, nicht einer pro View.

**Primäre Empfehlung:** `RealtimeService` als `@MainActor ObservableObject`-Singleton, der alle drei Subscriptions in einem einzigen Channel hält. `scenePhase == .active` → REST-Refetch + channel re-subscribe. `scenePhase == .background` → `supabase.realtime.disconnectSocket()`. Widget-Daten ausschließlich via App Group (kein Netzwerk im Widget für Phase 5).

---

<phase_requirements>
## Phase Requirements

| ID | Beschreibung | Research-Grundlage |
|----|-------------|-------------------|
| SYNC-01 | Score und Ringe anderer Familienmitglieder aktualisieren live ohne App-Neustart | Supabase Realtime Postgres Changes auf `activity_entries` + `weekly_summaries`; scenePhase-gated subscribe/unsubscribe |
| SYNC-02 | Aktivitäts-Feed aktualisiert live wenn ein Familienmitglied etwas einträgt | Gleicher Realtime-Channel wie SYNC-01; INSERT-Action → prepend entry to feed |
| SYNC-03 | Push-Notification wenn ein Familienmitglied eine Aktivität einträgt (opt-in) | Supabase Edge Function (Database Webhook on activity_entries INSERT) → APNs via JWT p8; device_push_tokens-Tabelle in DB |
| WIDGET-01 | Lock-Screen-Widget (accessoryCircular): heutiger Score-Ring | `WidgetFamily.accessoryCircular`; `Gauge`-View oder `Circle().trim()`; Daten aus App Group UserDefaults (WidgetData-Struct erweitern um `todayScore: Double, todayGoal: Double`) |
| WIDGET-02 | Lock-Screen-Widget (accessoryRectangular): Schnelleintrag — Kategorie antippen | Deep Link `familyscore://log?category=haushalt`; `.onOpenURL` in App; accessoryRectangular = 4 Kategorie-Buttons als Deep-Link-`Link`-Views |
| WIDGET-03 | Home-Screen-Widget groß: Familienübersicht Ranking | `WidgetFamily.systemLarge`; alle Member aus WidgetData.members; MemberRow-View mit Name + wöchentlichen Punkten |
| WIDGET-04 | Home-Screen-Widget groß: Quick-Entry mit AppIntent (iOS 17+) | `AppIntentConfiguration` + `AppIntent.perform()`; `Button(intent:)`; iOS 17+ only — auf iOS 16 Gerät nur tippen → App-Start |
| WIDGET-05 | Home-Screen-Widget mittel: Meine 3 persönlichen Ringe | `WidgetFamily.systemMedium`; `WidgetData` um `myDutyProgress: Double, myLeisureProgress: Double, myScoreProgress: Double` erweitern |
</phase_requirements>

---

## Project Constraints (aus CLAUDE.md)

| Direktive | Auswirkung auf Phase 5 |
|-----------|----------------------|
| Supabase SDK NUR im Hauptapp-Target | `RealtimeService` lebt nur im App-Target; Widget liest ausschließlich App Group UserDefaults |
| Realtime stirbt im iOS-Hintergrund | `RealtimeService` muss `supabase.realtime.disconnectSocket()` bei `.background` aufrufen und bei `.active` REST-fetch + re-subscribe |
| App Group muss im Apple Developer Portal für BEIDE Targets registriert sein | Vor Widget-UI-Implementierung: App Group SC-2 auf physischem Gerät verifizieren (Simulator ignoriert Portal-Entitlements) |
| Datenaustausch nur via UserDefaults(suiteName: "group.com.familyscore") | WidgetData-Struct als einzige Datenquelle für alle Widget-Oberflächen |
| Nach Realtime-Update → App schreibt in App Group → WidgetCenter.shared.reloadAllTimelines() | WidgetDataWriter muss nach jedem Realtime-Event aufgerufen werden |
| Lock Screen Widgets (accessory*): iOS 16+ | accessoryCircular und accessoryRectangular sind verfügbar — kein Feature-Flag nötig |
| Interaktive Widget-Buttons (AppIntents): iOS 17+ | WIDGET-04 braucht `#available(iOS 17, *)` Guard; auf iOS 16 zeigt Widget statischen Inhalt |
| ObservableObject + @Published (NICHT @Observable) | iOS 16.0 Minimum; RealtimeService und alle Services verwenden ObservableObject |
| Score NIEMALS als mutabler Wert speichern | WidgetData.weeklyPoints kommt aus `weekly_summaries`-Abfrage nach Realtime-Event — nie client-seitig akkumuliert |
| XCTestConfigurationFilePath-Guard | RealtimeService.startListening() muss diesen Guard enthalten; Supabase Realtime hängt in CI |

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Realtime-Subscription verwalten | App (RealtimeService) | Supabase Realtime WebSocket | Ein Singleton-Channel pro family_id; Lifecycle an scenePhase gebunden |
| App Group beschreiben | App (WidgetDataWriter) | — | Nur Hauptapp hat Supabase-Zugriff; Widget liest readonly |
| Widget-Timeline bereitstellen | Widget Extension (FamilyScoreProvider) | App Group UserDefaults | getTimeline() liest aus App Group; kein direkter Netzwerkaufruf für Phase 5 |
| Widget-Refresh triggern | App (via WidgetCenter.reloadAllTimelines) | iOS OS (Budget-Refresh) | App ruft reload nach Realtime-Event; OS refresht auf Budget-Basis als Fallback |
| AppIntent ausführen (WIDGET-04) | App Extension + App | — | `perform()` schreibt in App Group, App-Start holt frische Daten |
| Deep Link routen (WIDGET-02) | App (FamilyScoreApp.onOpenURL) | — | URL scheme `familyscore://` öffnet ActivityLogSheet direkt |
| Push-Benachrichtigung senden | Supabase Edge Function | APNs | Edge Function reagiert auf activity_entries INSERT via Database Webhook |
| Push-Token speichern | App (UserService) | Supabase DB (device_push_tokens) | App registriert für Benachrichtigungen, speichert APNs-Token in DB |
| Widget-Push-Token verwalten (SYNC-03 Stretch) | Widget Extension (WidgetPushHandler) | App | WidgetPushHandler gibt separaten Token für Widget-Push; komplex, Wave 3 |
| Lock Screen Widget-Daten | FamilyScoreKit (WidgetData) | App Group UserDefaults | WidgetData-Struct muss um todayScore-Felder erweitert werden |

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| supabase-swift | 2.46.0 | Realtime-Channel, Postgres Changes | Bereits installiert; einziges offizielles Swift-SDK; Realtime-v2-API |
| WidgetKit | System (iOS 16+) | Widget Extension, Timeline Provider | Apple System Framework; kein Ersatz |
| AppIntents | System (iOS 16+) | Intent-Definitionen für WIDGET-04 | Apple System Framework; `Button(intent:)` erst iOS 17 |
| FamilyScoreKit (lokal) | Phase 1 | WidgetData Struct — shared zwischen App + Widget | Bereits vorhanden; muss um todayScore-Felder erweitert werden |
| UserNotifications | System (iOS 10+) | Push Permission Request, APNs-Token | Apple System Framework |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Foundation (URLSession) | System | Widget-Fallback-Fetch im getTimeline() | Nur als letzter Fallback wenn App Group leer ist — Wave 3 |
| SwiftUI Link | System (iOS 16+) | Deep Link aus accessoryRectangular-Widget | Kein URL-Schema-Handling im Widget; `Link`-View navigiert zur App |

### Alternativen abgelehnt

| Statt | Könnte man | Warum abgelehnt |
|-------|-----------|-----------------|
| App Group UserDefaults | Supabase SDK direkt im Widget | 30MB Speicher-Limit; Architekturgesetz aus Phase 1 |
| Supabase Realtime | Firebase Realtime DB | Supabase bereits im Stack; kein zweites Backend |
| Supabase Edge Function + APNs | OneSignal / Expo Push | Externe Services = Abhängigkeit + Kosten; eigene APNs-Integration ist möglich |
| Deep Link aus Widget-Tap | `AppIntent` für WIDGET-02 | accessoryRectangular hat kein Button(intent:) Support auf iOS 16; Deep Link ist sicherer |

---

## Architecture Patterns

### System-Architektur (Datenfluss Phase 5)

```
Gerät A (Familienmitglied loggt Aktivität)
  │
  ▼
ActivityService.logActivity()
  │  INSERT in activity_entries (Supabase DB)
  │
  ├─────────────────────────────────────────────────────────────────┐
  │ Supabase DB Trigger                                             │
  │   → update_weekly_summary() aktualisiert weekly_summaries       │
  │   → supabase_realtime publikation feuert für activity_entries   │
  │      und weekly_summaries                                        │
  │                                                                 │
  │ Supabase Edge Function (Database Webhook)                       │
  │   → activity_entries INSERT → push_notification Funktion        │
  │   → APNs: sendet an alle anderen family member devices           │
  └─────────────────────────────────────────────────────────────────┘
                    │
        ┌───────────┴───────────────┐
        │                           │
        ▼                           ▼
Gerät B (anderes Familienmitglied)  APNs → Gerät B (opt-in Notification)
  │
  RealtimeService (Channel "family-{familyId}")
    │  Postgres Changes: activity_entries INSERT
    │  Postgres Changes: weekly_summaries UPDATE
    │
    ▼
  RealtimeService.handleChange()
    │  → ActivityService.entries aktualisieren
    │  → DashboardViewModel.refresh()
    │
    ▼
  WidgetDataWriter.update()
    │  → JSON encode(WidgetData) → UserDefaults(suiteName: "group.com.familyscore")
    │  → WidgetCenter.shared.reloadAllTimelines()
    │
    ▼
Widget Extension (separater Prozess)
    │  FamilyScoreProvider.getTimeline()
    │    → liest UserDefaults(suiteName: "group.com.familyscore")
    │    → decodes WidgetData
    │
    ▼
  Lock Screen Widget (WIDGET-01/02)
  Home Screen Widget (WIDGET-03/04/05)
    → UI aktualisiert
```

### Empfohlene Projektstruktur (Phase 5 Ergänzungen)

```
FamilyScore/
├── Services/
│   ├── AuthService.swift              ← Phase 2 (unverändert)
│   ├── FamilyService.swift            ← Phase 3 (unverändert)
│   ├── ActivityService.swift          ← Phase 4 (unverändert)
│   ├── RealtimeService.swift          ← NEU: Channel-Lifecycle, Reconnect
│   └── NotificationService.swift     ← NEU: APNs-Token, Permission-Request
├── Helpers/
│   └── WidgetDataWriter.swift         ← NEU: App Group schreiben + reload
├── Views/
│   ├── Dashboard/ ...                 ← Phase 4 (scenePhase-Handler ergänzen)
│   └── Notifications/
│       └── NotificationPermissionView.swift ← NEU: opt-in Prompt
FamilyScoreWidgetExtension/
├── FamilyScoreWidgetBundle.swift      ← Phase 1 (Widget-Liste erweitern)
├── Widgets/
│   ├── AccessoryCircularWidget.swift  ← NEU: WIDGET-01
│   ├── AccessoryRectangularWidget.swift ← NEU: WIDGET-02
│   ├── FamilyRankingWidget.swift      ← NEU: WIDGET-03
│   ├── QuickEntryWidget.swift         ← NEU: WIDGET-04 (AppIntent, iOS 17+)
│   └── PersonalRingsWidget.swift      ← NEU: WIDGET-05
├── Intents/
│   └── LogActivityIntent.swift        ← NEU: AppIntent für WIDGET-04
└── Providers/
    ├── FamilyScoreProvider.swift      ← Phase 1 Placeholder ersetzen
    └── WidgetData+AppGroup.swift     ← NEU: Lese-Helfer aus App Group
FamilyScoreKit/Sources/FamilyScoreKit/
└── WidgetData.swift                   ← Erweitern um todayScore-Felder
supabase/
├── functions/
│   └── push-notification/
│       └── index.ts                   ← NEU: Edge Function für SYNC-03
└── migrations/
    └── 20260517_phase5_push_tokens.sql ← NEU: device_push_tokens-Tabelle
```

---

## Pattern 1: RealtimeService — Channel-Lifecycle mit scenePhase

**Was:** Zentraler Service der einen einzigen Realtime-Channel für die Familie hält. Subscribed bei Foreground, unsubscribed bei Background, re-fetched bei Reconnect.

**Warum ein Channel:** Supabase Free Tier hat 200 concurrent WebSocket connections. Pro View einen Channel zu öffnen würde schnell zu Problemen führen. Ein einziger Channel pro Familie spart Verbindungen und vereinfacht die Lifecycle-Verwaltung.

```swift
// Source: supabase.com/docs/reference/swift/subscribe (VERIFIED)
// supabase.com/docs/reference/swift/removechannel (VERIFIED)
// PITFALLS.md Pattern — scenePhase-gated Re-subscribe (VERIFIED aus Projektwissen)

import Foundation
@preconcurrency import Supabase

@MainActor
final class RealtimeService: ObservableObject {

    private var channel: RealtimeChannelV2?
    private var listeningTask: Task<Void, Never>?

    // MARK: - Starten (scenePhase == .active)

    func startListening(familyId: UUID) async {
        // XCTest-Guard: Supabase Realtime haengt in CI 227s
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }

        // Falls bereits verbunden: nichts tun
        if channel?.status == .subscribed { return }

        // Cleanup alten Channel
        await stopListening()

        let ch = await supabase.channel("family-\(familyId.uuidString)")

        // Postgres Changes: activity_entries (INSERT + DELETE)
        let entryChanges = await ch.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "activity_entries",
            filter: .eq("family_id", value: familyId.uuidString)
        )

        // Postgres Changes: weekly_summaries (UPDATE)
        let summaryChanges = await ch.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "weekly_summaries",
            filter: .eq("family_id", value: familyId.uuidString)
        )

        await ch.subscribe()
        self.channel = ch

        // Events asynchron verarbeiten
        listeningTask = Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await change in entryChanges {
                        await self.handleActivityChange(change)
                    }
                }
                group.addTask {
                    for await change in summaryChanges {
                        await self.handleSummaryChange(change)
                    }
                }
            }
        }
    }

    // MARK: - Stoppen (scenePhase == .background)

    func stopListening() async {
        listeningTask?.cancel()
        listeningTask = nil
        if let ch = channel {
            await supabase.removeChannel(ch)
            channel = nil
        }
    }

    // MARK: - Reconnect nach Foreground (REST-Fetch + Re-subscribe)

    func refetchAndResubscribe(familyId: UUID,
                                activityService: ActivityService) async {
        // 1. REST-Fetch zuerst — Realtime-Events koennen waehrend Background verloren gehen
        await activityService.fetchTodayEntries(familyId: familyId)
        // 2. Dann neu subscriben
        await startListening(familyId: familyId)
    }

    // MARK: - Event-Handler

    private func handleActivityChange(_ change: AnyAction) async {
        // ActivityService und WidgetDataWriter via Environment oder Closure informieren
        // Konkrete Implementierung: Notification oder Closure-Callback
        switch change {
        case .insert(let action):
            if let entry = try? action.decodeRecord(as: ActivityEntry.self) {
                await activityDidInsert(entry)
            }
        case .delete(let action):
            let id = action.oldRecord["id"]?.stringValue
            if let id { await activityDidDelete(id: id) }
        default: break
        }
        // Nach jeder Aenderung Widget-Cache aktualisieren
        await WidgetDataWriter.shared.updateAndReload()
    }

    private func handleSummaryChange(_ change: AnyAction) async {
        // Weekly summary hat sich veraendert → Dashboard neu laden
        await WidgetDataWriter.shared.updateAndReload()
    }
}
```

**In FamilyScoreApp.swift (scenePhase-Integration):**

```swift
// Source: PITFALLS.md Realtime Silent Disconnection (VERIFIED)
// Source: CLAUDE.md "Realtime stirbt im iOS-Hintergrund" (VERIFIED)

.onChange(of: scenePhase) { _, newPhase in
    guard let familyId = authService.currentFamilyId else { return }
    if newPhase == .active {
        Task {
            await realtimeService.refetchAndResubscribe(
                familyId: familyId,
                activityService: activityService
            )
        }
    } else if newPhase == .background {
        Task { await realtimeService.stopListening() }
    }
}
```

---

## Pattern 2: WidgetData erweitern — todayScore-Felder

**Was:** `WidgetData`-Struct in `FamilyScoreKit` muss um Felder für die heutigen Tagesscores erweitert werden. Phase 1 hat nur `weeklyPoints` und `weeklyMinutes`.

**WICHTIG:** FamilyScoreKit darf KEINEN Supabase-Import haben. Alle Werte müssen vom App-Target berechnet und geschrieben werden.

```swift
// Quell-Datei: FamilyScoreKit/Sources/FamilyScoreKit/WidgetData.swift
// Erweiterung gegenüber Phase 1 — rückwärtskompatibel (neue optionale Felder)

public struct WidgetData: Codable, Sendable {
    public struct MemberScore: Codable, Sendable {
        public let displayName: String
        public let avatarInitial: String
        public let avatarColor: String      // NEU: Hex-String für Mini-Avatar
        public let weeklyPoints: Double
        public let weeklyMinutes: Int
        // ...init...
    }

    // Bestehende Felder (Phase 1)
    public let familyName: String
    public let members: [MemberScore]
    public let lastUpdated: Date

    // NEU für Phase 5 Widgets
    public let myDutyProgress: Double      // WIDGET-05: Pflicht-Ring (0.0–1.0+)
    public let myLeisureProgress: Double   // WIDGET-05: Freizeit-Ring
    public let myScoreProgress: Double     // WIDGET-05: Score-Ring
    public let myTodayScore: Int           // WIDGET-01: heutiger Score
    public let myTodayScoreGoal: Int       // WIDGET-01: Ziel (z.B. 60 Punkte)
}
```

---

## Pattern 3: WidgetDataWriter — App Group schreiben

**Was:** Zentraler Schreiber der nach jedem Realtime-Event den App-Group-Cache aktualisiert und `WidgetCenter.shared.reloadAllTimelines()` aufruft.

```swift
// Source: ARCHITECTURE.md Pattern (VERIFIED), WidgetKit-Docs (VERIFIED)
// Datei: FamilyScore/Helpers/WidgetDataWriter.swift

import Foundation
import WidgetKit
import FamilyScoreKit

@MainActor
final class WidgetDataWriter {
    static let shared = WidgetDataWriter()
    private let defaults = UserDefaults(suiteName: appGroupIdentifier)!

    func write(_ data: WidgetData) {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        defaults.set(encoded, forKey: "widgetData")
        // Kein synchronize() nötig — iOS schreibt automatisch
        WidgetCenter.shared.reloadAllTimelines()
    }

    func updateAndReload() async {
        // Wird von RealtimeService nach jedem Change aufgerufen
        // Holt aktuelle Daten aus ActivityService/FamilyService und schreibt sie
        // Konkrete Implementierung braucht Referenz auf aktuellen State
    }
}
```

**In der Widget Extension — TimelineProvider lesen:**

```swift
// Source: ARCHITECTURE.md Pattern (VERIFIED)
// Datei: FamilyScoreWidgetExtension/Providers/WidgetData+AppGroup.swift

import Foundation
import FamilyScoreKit

extension WidgetData {
    static func readFromAppGroup() -> WidgetData? {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: "widgetData"),
              let widgetData = try? JSONDecoder().decode(WidgetData.self, from: data)
        else { return nil }
        return widgetData
    }
}

// In FamilyScoreProvider.getTimeline():
func getTimeline(in context: Context,
                 completion: @escaping (Timeline<FamilyScoreEntry>) -> Void) {
    let data = WidgetData.readFromAppGroup() ?? .placeholder
    let entry = FamilyScoreEntry(date: .now, data: data)
    // Stündlicher Fallback — bei normalem Betrieb wird via reloadAllTimelines() refresht
    let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
    completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
}
```

---

## Pattern 4: Widget-Familien — was welches Widget benötigt

**Was:** Fünf Widget-Konfigurationen in `FamilyScoreWidgetBundle`. iOS-Architektur erlaubt mehrere `Widget`-Typen im Bundle.

```swift
// Source: Apple WidgetKit Docs (VERIFIED via ARCHITECTURE.md)
// Datei: FamilyScoreWidgetExtension/FamilyScoreWidgetBundle.swift

@main
struct FamilyScoreWidgetBundle: WidgetBundle {
    var body: some Widget {
        ScoreRingWidget()          // WIDGET-01: accessoryCircular
        QuickEntryWidget()         // WIDGET-02: accessoryRectangular
        FamilyRankingWidget()      // WIDGET-03: systemLarge
        QuickActionWidget()        // WIDGET-04: systemLarge + AppIntent (iOS 17+)
        PersonalRingsWidget()      // WIDGET-05: systemMedium
    }
}
```

### WIDGET-01: accessoryCircular (Lock Screen Score-Ring)

```swift
// Source: Apple WidgetKit Docs accessoryCircular (VERIFIED)
// Constraints: Monochromer Rendermodus auf älteren Geräten (kein OLED Always On)
// PITFALLS.md: Lock Screen Widgets monochrome-first designen

struct ScoreRingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ScoreRing", provider: FamilyScoreProvider()) { entry in
            ScoreRingView(entry: entry)
        }
        .configurationDisplayName("Mein Score")
        .description("Zeigt deinen heutigen Score.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct ScoreRingView: View {
    let entry: FamilyScoreEntry
    var body: some View {
        // Gauge: speziell fuer accessoryCircular designed (iOS 16+)
        // Source: Apple Developer Docs — Gauge in accessoryCircular (VERIFIED)
        Gauge(value: Double(entry.data.myTodayScore),
              in: 0...Double(entry.data.myTodayScoreGoal)) {
            Image(systemName: "star.fill")
        } currentValueLabel: {
            Text("\(entry.data.myTodayScore)")
                .font(.system(size: 14, weight: .bold))
        }
        .gaugeStyle(.accessoryCircular)
        .widgetAccentable()  // Akzentfarbe aus Systemeinstellung nutzen
    }
}
```

### WIDGET-02: accessoryRectangular (Lock Screen Schnelleintrag als Deep Links)

```swift
// Deep Link statt AppIntent — accessoryRectangular hat KEIN Button(intent:) auf iOS 16
// Source: VERIFIED — AppIntents Button ist nur iOS 17+ Home Screen, nicht Lock Screen
// Strategie: Link(destination: URL) in jedem Kategorie-Button

struct QuickEntryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "QuickEntry", provider: FamilyScoreProvider()) { entry in
            QuickEntryView(entry: entry)
        }
        .configurationDisplayName("Schnelleintrag")
        .description("Kategorie antippen zum Eintragen.")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct QuickEntryView: View {
    let entry: FamilyScoreEntry
    // 4 Kategorien als URL-Deep-Links (accessoryRectangular: 170x76 pt ca.)
    let categories: [(name: String, icon: String, urlPath: String)] = [
        ("Haushalt", "house.fill", "haushalt"),
        ("Freizeit", "gamecontroller.fill", "freizeit"),
        ("Besorgungen", "bag.fill", "besorgungen"),
        ("Arbeit", "book.fill", "arbeit")
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(categories, id: \.name) { cat in
                Link(destination: URL(string: "familyscore://log?category=\(cat.urlPath)")!) {
                    VStack(spacing: 2) {
                        Image(systemName: cat.icon)
                            .font(.system(size: 14))
                        Text(cat.name)
                            .font(.system(size: 9))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .widgetURL(URL(string: "familyscore://")!)  // Fallback wenn nicht-Button-Bereich
    }
}
```

### WIDGET-03: systemLarge Familienübersicht

```swift
struct FamilyRankingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FamilyRanking", provider: FamilyScoreProvider()) { entry in
            FamilyRankingView(entry: entry)
        }
        .configurationDisplayName("Familienübersicht")
        .description("Wochenpunkte aller Familienmitglieder.")
        .supportedFamilies([.systemLarge])
    }
}

struct FamilyRankingView: View {
    let entry: FamilyScoreEntry
    var sortedMembers: [WidgetData.MemberScore] {
        entry.data.members.sorted { $0.weeklyPoints > $1.weeklyPoints }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.data.familyName)
                .font(.headline)
            ForEach(sortedMembers.indices, id: \.self) { i in
                let member = sortedMembers[i]
                HStack {
                    // Rang-Nummer
                    Text("\(i + 1).")
                        .font(.caption).foregroundStyle(.secondary)
                    // Avatar-Kreis
                    Circle()
                        .fill(Color(hex: member.avatarColor) ?? .blue)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text(member.avatarInitial).font(.caption).foregroundColor(.white)
                        )
                    Text(member.displayName)
                    Spacer()
                    Text("\(Int(member.weeklyPoints)) Pkt")
                        .font(.caption).monospacedDigit()
                }
            }
            Text("Stand: \(entry.data.lastUpdated, style: .relative) her")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
```

### WIDGET-04: systemLarge Quick-Entry mit AppIntent (iOS 17+)

```swift
// Source: Apple AppIntents Docs (VERIFIED — AppIntentConfiguration, Button(intent:))
// WICHTIG: AppIntent.perform() darf KEIN Netzwerkaufruf machen — Widget 30MB Limit
// Strategie: perform() schreibt einen "pending_log"-Eintrag in App Group;
//            App liest beim naechsten Foreground und loggt tatsaechlich

struct LogActivityIntent: AppIntent {
    static let title: LocalizedStringResource = "Aktivität eintragen"

    @Parameter(title: "Kategorie")
    var categorySlug: String  // "haushalt", "freizeit" etc.

    func perform() async throws -> some IntentResult {
        // Schreibt pending_log in App Group — App loggt beim naechsten Start
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return .result()
        }
        var pending = (defaults.array(forKey: "pendingLogs") as? [[String: String]]) ?? []
        pending.append(["category": categorySlug, "timestamp": ISO8601DateFormatter().string(from: .now)])
        defaults.set(pending, forKey: "pendingLogs")
        return .result()
    }
}

struct QuickActionWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "QuickAction", provider: FamilyScoreProvider()) { entry in
            if #available(iOS 17, *) {
                QuickActionView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                // iOS 16 Fallback: tap öffnet App via widgetURL
                Text("Öffne App zum Eintragen")
                    .widgetURL(URL(string: "familyscore://log")!)
            }
        }
        .configurationDisplayName("Schnelleintrag")
        .description("Aktivität direkt vom Widget eintragen.")
        .supportedFamilies([.systemLarge])
    }
}

@available(iOS 17, *)
struct QuickActionView: View {
    let entry: FamilyScoreEntry
    let actions: [(label: String, icon: String, slug: String)] = [
        ("Haushalt", "house.fill", "haushalt"),
        ("Freizeit", "gamecontroller.fill", "freizeit"),
        ("Besorgungen", "bag.fill", "besorgungen"),
        ("Arbeit/Schule", "book.fill", "arbeit")
    ]
    var body: some View {
        VStack(spacing: 12) {
            Text("Was hast du gemacht?").font(.headline)
            ForEach(actions, id: \.slug) { action in
                Button(intent: LogActivityIntent(categorySlug: action.slug)) {
                    Label(action.label, systemImage: action.icon)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}
```

### WIDGET-05: systemMedium Meine 3 Ringe

```swift
struct PersonalRingsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PersonalRings", provider: FamilyScoreProvider()) { entry in
            PersonalRingsView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Meine Ringe")
        .description("Deine heutigen Pflicht-, Freizeit- und Score-Ringe.")
        .supportedFamilies([.systemMedium])
    }
}

struct PersonalRingsView: View {
    let entry: FamilyScoreEntry
    var body: some View {
        HStack(spacing: 16) {
            // Ringe aus Phase 4 (kleinere Version)
            MiniRingClusterView(
                dutyProgress: entry.data.myDutyProgress,
                leisureProgress: entry.data.myLeisureProgress,
                scoreProgress: entry.data.myScoreProgress
            )
            VStack(alignment: .leading, spacing: 4) {
                Label("Pflicht", systemImage: "house.fill")
                    .foregroundColor(.red)
                Label("Freizeit", systemImage: "gamecontroller.fill")
                    .foregroundColor(.green)
                Label("Score", systemImage: "star.fill")
                    .foregroundColor(.blue)
                    .font(.caption)
                Spacer()
                Text("Stand: \(entry.data.lastUpdated, style: .relative) her")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding()
    }
}
```

---

## Pattern 5: Deep Link Routing — WIDGET-02

**Was:** accessoryRectangular-Widget öffnet die App via URL-Scheme und zeigt direkt die `ActivityLogSheet` für die gewählte Kategorie.

```swift
// In FamilyScoreApp.swift — .onOpenURL Handler

.onOpenURL { url in
    guard url.scheme == "familyscore" else { return }
    if url.host == "log", let query = url.queryItems {
        let category = query.first(where: { $0.name == "category" })?.value
        // AppState über Notification oder EnvironmentObject mitteilen
        NotificationCenter.default.post(
            name: .openQuickLog,
            object: nil,
            userInfo: ["category": category as Any]
        )
    }
}

extension Notification.Name {
    static let openQuickLog = Notification.Name("openQuickLog")
}
```

**URL-Scheme muss in Info.plist registriert sein:**
```xml
<!-- Info.plist — wird über XcodeGen project.yml generiert -->
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>familyscore</string>
    </array>
  </dict>
</array>
```

**WIDGET-04 pending_log Consumer in App:**

```swift
// In FamilyScoreApp.swift oder ActivityService
// Aufgerufen bei scenePhase == .active

func drainPendingWidgetLogs() async {
    guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
          let pending = defaults.array(forKey: "pendingLogs") as? [[String: String]],
          !pending.isEmpty
    else { return }

    defaults.removeObject(forKey: "pendingLogs")

    for log in pending {
        guard let slug = log["category"],
              let category = categoryForSlug(slug) else { continue }
        // Retroaktiver Eintrag: Zeitstempel aus pending_log verwenden
        let timestamp = log["timestamp"].flatMap { ISO8601DateFormatter().date(from: $0) } ?? .now
        let minutes = max(1, Int(Date.now.timeIntervalSince(timestamp) / 60))
        try? await activityService.logActivity(
            categoryId: category.id,
            durationMinutes: minutes,
            title: "Widget-Eintrag"
        )
    }
}
```

---

## Pattern 6: Push-Benachrichtigung (SYNC-03) — APNs via Supabase Edge Function

**Was:** Opt-in Push-Benachrichtigung wenn ein Familienmitglied eine Aktivität einträgt. Technischer Weg: Database Webhook → Supabase Edge Function → APNs HTTP/2.

**APNs-Authentifizierung:** JWT-basiert mit `.p8`-Key (kein Zertifikat nötig). Supabase Edge Functions laufen in Deno; JWT-Signierung ist mit `jose`-Bibliothek möglich. Der `.p8`-Key wird als Supabase Secret gespeichert.

**Neue DB-Tabelle: device_push_tokens**

```sql
-- Datei: supabase/migrations/20260517_phase5_push_tokens.sql

CREATE TABLE public.device_push_tokens (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  family_id   uuid not null references public.families(id) on delete cascade,
  apns_token  text not null,
  device_name text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  UNIQUE (user_id, apns_token)
);

CREATE INDEX device_push_tokens_family_id ON public.device_push_tokens(family_id);

ALTER TABLE public.device_push_tokens ENABLE ROW LEVEL SECURITY;

-- User kann eigene Token schreiben und lesen
CREATE POLICY "User verwaltet eigene Push-Tokens"
  ON public.device_push_tokens FOR ALL TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- Edge Function braucht Service-Role (umgeht RLS) um alle Familien-Token zu lesen
-- KEIN Client-seitiger Zugriff auf andere Token — keine zusaetzliche SELECT-Policy
```

**Swift — APNs-Token registrieren:**

```swift
// Datei: FamilyScore/Services/NotificationService.swift
import UserNotifications

@MainActor
final class NotificationService: ObservableObject {
    @Published var isAuthorized: Bool = false
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    // Opt-in: User muss aktiv zustimmen
    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        } catch {
            isAuthorized = false
        }
    }

    // Wird in AppDelegate/SceneDelegate aufgerufen nach didRegisterForRemoteNotificationsWithDeviceToken
    func saveToken(_ deviceToken: Data, familyId: UUID, userId: UUID) async {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        struct PushToken: Encodable {
            let user_id: String
            let family_id: String
            let apns_token: String
        }
        try? await supabase
            .from("device_push_tokens")
            .upsert(PushToken(
                user_id: userId.uuidString,
                family_id: familyId.uuidString,
                apns_token: tokenString
            ))
            .execute()
    }
}
```

**Supabase Edge Function (TypeScript/Deno) — Grundstruktur:**

```typescript
// supabase/functions/push-notification/index.ts
// Source: Supabase Edge Function Docs (VERIFIED Pattern);
//         APNs HTTP/2 JWT Auth (ASSUMED — standard APNs approach)

interface WebhookPayload {
  type: 'INSERT';
  table: 'activity_entries';
  record: {
    id: string;
    family_id: string;
    user_id: string;
    // ...
  };
}

Deno.serve(async (req) => {
  const payload: WebhookPayload = await req.json();

  // Service-Role-Client um RLS zu umgehen (liest alle family member tokens)
  const { data: tokens } = await supabaseAdmin
    .from('device_push_tokens')
    .select('apns_token, user_id')
    .eq('family_id', payload.record.family_id)
    .neq('user_id', payload.record.user_id);  // Eigenen Token nicht benachrichtigen

  // APNs JWT erzeugen (jose + APNS_P8_KEY Secret)
  // An alle anderen Familienmitglieder schicken
  for (const { apns_token } of tokens ?? []) {
    await sendApnsNotification(apns_token, {
      aps: {
        alert: {
          title: "Neue Aktivität",
          body: "Ein Familienmitglied hat etwas eingetragen!"
        },
        'content-available': 1
      }
    });
  }

  return new Response('OK');
});
```

**Supabase Secrets (nicht in Git):**
- `APNS_P8_KEY` — Apple Developer Portal → Keys → .p8 Inhalt
- `APNS_KEY_ID` — Key-ID aus Portal
- `APNS_TEAM_ID` — Apple Team ID
- `APNS_BUNDLE_ID` — `com.familyscore`

**Database Webhook Setup (Supabase Dashboard):**
- Table: `activity_entries`
- Event: INSERT
- Webhook URL: `{supabase-project-url}/functions/v1/push-notification`
- HTTP Method: POST
- HTTP Headers: `Authorization: Bearer {supabase-service-role-key}`

---

## Don't Hand-Roll

| Problem | Nicht bauen | Stattdessen | Warum |
|---------|-------------|-------------|-------|
| Widget-Datenaustausch | Netzwerkcall im Widget | App Group UserDefaults + WidgetDataWriter | 30MB Widget-Limit; Architekturgesetz Phase 1; kein Supabase im Widget |
| Widget-Budget-Throttling umgehen | `Timer` oder Background Task | `WidgetCenter.shared.reloadAllTimelines()` nach Realtime-Event | iOS Budget ist unvermeidbar; reloadAllTimelines ist das korrekte API |
| Realtime-Reconnect-Loop | Eigener Retry-Mechanismus mit Timer | scenePhase-gated unsubscribe/subscribe + REST-Refetch | Supabase supabase-swift hat eigenes Backoff; manuelles Retry verursacht SUBSCRIBED/CLOSED-Loop (bekannter Bug) |
| APNs-Token-Verwaltung | Hardcoded Token | DB-Tabelle `device_push_tokens` + upsert bei jedem App-Start | Tokens rotieren; mehrere Geräte pro User; Token-Ablauf muss abgefangen werden |
| Lock Screen Widget-Farben | Vollfarbiges Design | Monochrome-first + `.widgetAccentable()` | Lock Screen rendert grayscale auf Non-OLED-Geräten (PITFALLS.md) |
| AppIntent Netzwerkaufruf | Supabase INSERT in perform() | pending_log in App Group + App drainiert beim Foreground | 30MB Widget-Limit; perform() läuft im Widget-Prozess |

---

## Common Pitfalls

### Pitfall 1: App Group nicht auf physischem Gerät verifiziert (SC-2)

**Was geht schief:** `UserDefaults(suiteName: "group.com.familyscore")` im Widget gibt auf physischem Gerät `nil` zurück — auf Simulator funktioniert alles. Widget zeigt Placeholder-Daten.

**Warum:** Apple Developer Portal: App Group muss für BEIDE App-IDs registriert sein (Haupt-App + Widget Extension). Simulator ignoriert Portal-Entitlements.

**Wie vermeiden:** SC-2 aus Phase 1 (App Group Device Verification) muss als allererstes in Phase 5 abgehakt werden, bevor Widget-UI implementiert wird.

**Warnung:** PITFALLS.md "App Group Entitlement Mismatch" — CRITICAL.

---

### Pitfall 2: Realtime SUBSCRIBED→CLOSED Loop nach Reconnect

**Was geht schief:** Nach Foreground-Rückkehr versucht `startListening()` zu subscriben. Status wechselt zwischen SUBSCRIBED und CLOSED in einer Schleife. Events kommen nie an.

**Warum:** Bekannter Supabase-Swift-Bug (GitHub Discussion #27513). Tritt auf wenn unsubscribe und sofort subscribe aufgerufen wird.

**Wie vermeiden:**
1. Immer `await supabase.removeChannel(channel)` aufrufen und auf Completion warten bevor neu subscribiert wird
2. Bei Foreground: kurze `Task { try? await Task.sleep(nanoseconds: 100_000_000) }` (100ms) zwischen removeChannel und neuem subscribe
3. Realtime-Status nicht als Retry-Trigger verwenden — nur scenePhase steuert die Lifecycle

---

### Pitfall 3: XCTestConfigurationFilePath-Guard in RealtimeService vergessen

**Was geht schief:** CI-Tests crashen mit `signal trap` weil Supabase Realtime versucht, einen WebSocket zu `placeholder.supabase.co` aufzubauen und 227 Sekunden hängt.

**Warum:** XCTest initialisiert die App und ruft Lifecycle-Methoden auf. Ohne Guard schlägt der Test-Host fehl.

**Wie vermeiden:**
```swift
guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
    return
}
```
Diese Zeile MUSS in `RealtimeService.startListening()` als erstes stehen. Pattern aus CLAUDE.md Kritischen Architektur-Regeln.

---

### Pitfall 4: Widget Budget — reloadAllTimelines() wird throttled

**Was geht schief:** Nach jedem Realtime-Event wird `WidgetCenter.shared.reloadAllTimelines()` aufgerufen, aber iOS honored den Request nur 40-70 Mal pro Tag. Bei häufigen Updates (mehrere Aktivitäten in kurzer Zeit) wird Widget-Refresh gedrosselt.

**Warum:** iOS Budget-Mechanismus für Battery und Performance.

**Wie vermeiden:**
- Debounce `reloadAllTimelines()` Aufrufe: nach 5 Sekunden Stille tatsächlich aufrufen
- Widget zeigt `lastUpdated`-Zeitstempel sodass User weiß wenn Daten leicht veraltet sind
- Erwartungsmanagement: Widget-Daten können 15-30 Minuten hinken — ist kein Bug

---

### Pitfall 5: 30MB Widget-Limit durch Avatar-Bilder

**Was geht schief:** `FamilyRankingWidget` zeigt Avatar-Bilder. Widget-Extension überschreitet 30MB. Widget zeigt "Unable to load" ohne Fehlermeldung.

**Warum:** Jedes Bild-Asset im Widget-Prozess zählt gegen das 30MB-Limit. PITFALLS.md "30 MB Hard Memory Limit — No Warning, Just Termination".

**Wie vermeiden:**
- Avatare als Text-Initial in farbigen Kreisen (String + Color) — keine Bild-Assets
- `Color(hex:)` Extension verwenden um avatar_color Hex-String zu rendern
- Keine SF-Symbol-Varianten die große Bitmaps erzeugen — bei `.resizable()` vorsichtig sein

---

### Pitfall 6: Lock Screen Widget Farblosigkeit ignoriert

**Was geht schief:** `accessoryCircular` Score-Ring wird farbig designed. Auf iPhone SE, iPhone 14 (kein Always-On-Display) rendert der Lock Screen alle Widget-Inhalte grayscale.

**Warum:** Lock Screen-Widgets respektieren nur die "Akzentfarbe" via `.widgetAccentable()` — alle anderen Farben werden ignoriert.

**Wie vermeiden:**
- `Gauge`-View mit `.gaugeStyle(.accessoryCircular)` — System rendert korrekt als Ring
- `.widgetAccentable()` für primäre Werte
- Auf physischem Gerät testen (Simulator zeigt Lock Screen korrekt — Gerät nicht immer)

---

### Pitfall 7: URL-Scheme nicht in Info.plist registriert → Deep Links schweigen

**Was geht schief:** Widget-Button mit `Link(destination: URL(string: "familyscore://log?category=haushalt")!)` tut nichts wenn getippt. App wird nicht geöffnet.

**Warum:** iOS kann `familyscore://` nicht der App zuordnen wenn kein `CFBundleURLSchemes`-Eintrag in `Info.plist`.

**Wie vermeiden:** URL-Scheme in `project.yml` (XcodeGen) eintragen. Dieser Schritt muss in Wave 0 geprüft werden.

---

### Pitfall 8: AppIntents und Widget Extension-Membership

**Was geht schief:** `LogActivityIntent` ist im Haupt-App-Target definiert. Widget Extension kann ihn nicht finden. Build-Fehler oder Runtime-Crash.

**Warum:** AppIntents für Widgets müssen sowohl im App-Target als auch im Widget-Extension-Target verfügbar sein (entweder dual-target-membership oder in FamilyScoreKit).

**Wie vermeiden:** `LogActivityIntent` (und alle anderen AppIntents) in FamilyScoreKit als shared Package definieren — kein Supabase-Import nötig da perform() nur in App Group schreibt.

---

## Code Examples — Vollständige Patterns

### Supabase Realtime — Postgres Changes Subscribe (VERIFIED)

```swift
// Source: supabase.com/docs/reference/swift/subscribe (VERIFIED)
// Source: supabase.com/docs/reference/swift/removechannel (VERIFIED)

let ch = await supabase.channel("family-\(familyId.uuidString)")

let changes = await ch.postgresChange(
    AnyAction.self,
    schema: "public",
    table: "activity_entries",
    filter: .eq("family_id", value: familyId.uuidString)
)

await ch.subscribe()  // Achtung: MUSS nach postgresChange() aufgerufen werden

for await change in changes {
    switch change {
    case .insert(let action):
        print("Inserted: \(action.record)")
    case .delete(let action):
        print("Deleted: \(action.oldRecord)")
    default: break
    }
}

// Unsubscribe (scenePhase == .background):
await supabase.removeChannel(ch)
```

### WidgetCenter Reload (VERIFIED)

```swift
// Source: Apple WidgetKit Docs (VERIFIED)
import WidgetKit
WidgetCenter.shared.reloadAllTimelines()
// Kein Completion-Handler — fire and forget; iOS entscheidet wann es honored wird
```

### Gauge in accessoryCircular (VERIFIED API)

```swift
// Source: Apple Developer Docs — Gauge (VERIFIED iOS 16+)
Gauge(value: Double(todayScore), in: 0...Double(goal)) {
    Image(systemName: "star.fill")
} currentValueLabel: {
    Text("\(todayScore)")
}
.gaugeStyle(.accessoryCircular)
.widgetAccentable()
```

### AppIntent für Widget-Button (VERIFIED iOS 17+)

```swift
// Source: Apple AppIntents Docs (VERIFIED)
// Requires iOS 17.0+
struct LogActivityIntent: AppIntent {
    static let title: LocalizedStringResource = "Aktivität eintragen"
    @Parameter(title: "Kategorie") var categorySlug: String

    func perform() async throws -> some IntentResult {
        // NIEMALS Supabase/Network hier — Widget-Prozess, 30MB Limit
        // App Group schreiben ist erlaubt:
        let defaults = UserDefaults(suiteName: appGroupIdentifier)
        // ... schreiben ...
        return .result()
    }
}

// In Widget View (iOS 17+):
Button(intent: LogActivityIntent(categorySlug: "haushalt")) {
    Label("Haushalt", systemImage: "house.fill")
}
```

---

## State of the Art

| Alter Ansatz | Aktueller Ansatz | Geändert seit | Impact |
|--------------|-----------------|----------|--------|
| Channel per View | Ein Channel per Familie (Singleton) | Supabase Free Tier Limit bekannt | Spart Verbindungen; kein multiple-subscribe Bug |
| Widget macht direkten Netzwerkaufruf | App Group + WidgetCenter.reload | WidgetKit 1.0 (Best Practice) | Zuverlässig; kein 30MB-Limit-Problem |
| Alle Kategorien ohne `#available`-Guard | `AppIntentConfiguration` mit `#available(iOS 17, *)` | iOS 17 (2023) | Klare iOS-Version-Trennung; iOS 16 bekommt Deep-Link-Fallback |
| VoIP Push für Widget-Updates | `WidgetPushHandler` + `apns-push-type: widgets` | iOS 16 (introduziert) | Nicht VoIP; Widget-spezifischer Push-Typ mit eigenem Token |
| Supabase Broadcast für Push-Trigger | Database Webhook → Edge Function → APNs | Best Practice | Webhook ist zuverlässiger; kein WebSocket nötig auf Server |

---

## Assumptions Log

| # | Claim | Abschnitt | Risiko wenn falsch |
|---|-------|-----------|-------------------|
| A1 | APNs JWT-Signierung mit `.p8`-Key ist in Deno/Supabase Edge Functions via `jose`-Bibliothek möglich ohne File-System-Zugriff | Pattern 6 (Push) | Mittel: Einige Community-Reports zeigen Probleme mit p8-Key in Edge Functions. Falls blockiert: Expo Push Service als Fallback (dann aber externe Abhängigkeit). SYNC-03 als eigener Spike raten. |
| A2 | `WidgetPushHandler` (Widget-spezifischer APNs-Token) ist für Phase 5 nicht notwendig — die App-Group-Lösung ist ausreichend | Gesamtarchitektur | Niedrig: Widget-Push-Token würde Widget-Updates auch ohne laufende App ermöglichen; aber Budget-Limitierungen machen es wenig wertvoller als App-Group-Lösung. Spike empfohlen wenn Nutzer Widget-Updates ohne aktive App erwarten. |
| A3 | `FamilyScoreApp.swift` kann `.onChange(of: scenePhase)` sicher um `RealtimeService`-Calls erweitern ohne Konflikt mit bestehendem Auth-Observer | Pattern 1 | Niedrig: AuthService und RealtimeService sind unabhängige ObservableObjects; kein Shared-State-Konflikt erwartet. |
| A4 | `activity_entries` und `weekly_summaries` sind bereits in der Supabase Realtime-Publikation registriert (Phase 1 Migration) | Pattern 1 | Mittel: ARCHITECTURE.md zeigt `alter publication supabase_realtime add table ...` — muss in Phase 5 Wave 0 verifiziert werden. Falls nicht vorhanden, einfache SQL-Migration nötig. |
| A5 | `LogActivityIntent.perform()` darf in App Group schreiben und die App verarbeitet den Eintrag beim nächsten Foreground zuverlässig | Pattern 4 | Mittel: Wenn App nicht innerhalb ~24h in den Vordergrund kommt, gehen Widget-Logs verloren. Für eine Familien-App mit täglicher Nutzung akzeptabel. |
| A6 | accessoryRectangular hat KEIN `Button(intent:)` Support — nur `Link(destination:)` für Deep Links | Pattern 3 | Niedrig: Laut Apple Docs sind interaktive Widget-Controls (Button/Toggle) nur für systemSmall/Medium/Large (iOS 17+), nicht für accessory-Familien. Community-Berichte bestätigen. |

---

## Open Questions

1. **App Group SC-2 Verifikation (Blocker)**
   - Was wir wissen: Phase 1 hat App Group konfiguriert; Simulator-Tests passen
   - Was unklar ist: Ob die Widget Extension App-ID im Apple Developer Portal korrekt registriert ist
   - Empfehlung: Wave 0 Aufgabe — Sideloadly + `.ipa` auf physischem Gerät; `verifyAppGroup()` Debug-Funktion ist bereits in `FamilyScoreApp.swift` vorhanden

2. **Supabase Realtime-Publikation für activity_entries/weekly_summaries**
   - Was wir wissen: ARCHITECTURE.md listet `alter publication supabase_realtime add table activity_entries` als geplante Migration
   - Was unklar ist: Ob diese in der Phase-1-Migration tatsächlich ausgeführt wurde
   - Empfehlung: Wave 0 — Supabase Dashboard → Database → Publications prüfen; ggf. Migration einspielen

3. **APNs Edge Function Spike (SYNC-03)**
   - Was wir wissen: Supabase Edge Functions unterstützen TypeScript/Deno; APNs JWT-Auth ist dokumentiert; Community-Reports zeigen gemischte Erfahrungen mit p8-Key in Deno
   - Was unklar ist: Ob APNs JWT-Signierung mit `jose`-Bibliothek in Supabase Edge Functions stabil funktioniert
   - Empfehlung: SYNC-03 als separaten Wave 3 planen; Spike (Proof of Concept Edge Function) vor vollständiger Implementation

4. **WidgetData-Migration: Bestehende Phase-1-Struktur erweitern**
   - Was wir wissen: WidgetData.swift hat `weeklyPoints` und `weeklyMinutes`; Phase 5 braucht `myDutyProgress`, `myLeisureProgress`, `myScoreProgress`, `myTodayScore`, `myTodayScoreGoal`
   - Was unklar ist: Ob Phase 4 `WidgetDataWriter` bereits partiell implementiert hat und dieser Code berücksichtigt werden muss
   - Empfehlung: Wave 0 — vorhandene WidgetData.swift lesen, neue Felder als Optional hinzufügen um rückwärtskompatibel zu bleiben während Implementierung läuft

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| supabase-swift Realtime | SYNC-01, SYNC-02 | ✓ | 2.46.0 | — |
| WidgetKit | WIDGET-01 bis 05 | ✓ | iOS 16+ (System) | — |
| AppIntents Button(intent:) | WIDGET-04 | Nur iOS 17+ | iOS 17+ | `#available` Guard + Deep Link Fallback |
| Physisches iPhone | App Group SC-2, Lock Screen Widgets | Verfügbar (Sideloadly auf Windows) | iOS 16+ | — |
| Apple Developer Account | APNs Push Token, App Group Portal | ✓ (Phase 1 verwendet) | — | — |
| Supabase Edge Functions | SYNC-03 | ✓ | Free Tier | — |
| APNs p8 Key | SYNC-03 Edge Function | Noch nicht erstellt | — | Expo Push als Fallback (externe Abhängigkeit) |

**Missing dependencies:**
- APNs p8 Key: Muss im Apple Developer Portal erstellt werden (Keys → Create). Benötigt für SYNC-03.
- Keine blocking dependencies für WIDGET-01 bis 05 und SYNC-01/02.

---

## Validation Architecture

### Test-Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (FamilyScoreTests-Target aus Phase 2 vorhanden) |
| Config-Datei | Xcode-Projekt |
| Schnell-Run | `xcodebuild build -scheme FamilyScore -destination "generic/platform=iOS Simulator" -quiet` |
| Test-Run | `xcodebuild test -scheme FamilyScore -destination "platform=iOS Simulator,OS=17.5,name=iPhone 16"` |

### Phase Requirements → Test-Mapping

| Req ID | Verhalten | Test-Typ | Automatisierbar | Datei |
|--------|-----------|----------|-----------------|-------|
| SYNC-01 | RealtimeService startet/stoppt Channel korrekt | Unit (Mock) | ✓ | `RealtimeServiceTests.swift` Wave 0 |
| SYNC-01 | scenePhase-Handler ruft refetchAndResubscribe auf | Unit (Mock) | ✓ | `RealtimeServiceTests.swift` |
| SYNC-01 | XCTestConfigurationFilePath-Guard verhindert echten Connect | Unit | ✓ | `RealtimeServiceTests.swift` |
| SYNC-02 | INSERT-Change aktualisiert ActivityService.entries | Unit (Mock) | ✓ | `RealtimeServiceTests.swift` |
| SYNC-02 | Feed-Update triggert WidgetDataWriter | Unit (Mock) | ✓ | `RealtimeServiceTests.swift` |
| SYNC-03 | APNs-Token wird in device_push_tokens gespeichert | Integration (Gerät) | ✗ | Gerät-Checkpoint |
| SYNC-03 | Edge Function sendet Push an andere Familienmitglieder | Manuell (zwei Geräte) | ✗ | Gerät-Checkpoint |
| WIDGET-01..05 | WidgetDataWriter.write() schreibt in App Group | Unit | ✓ | `WidgetDataWriterTests.swift` |
| WIDGET-01..05 | Widget liest korrekt aus App Group | Unit | ✓ | `WidgetDataWriterTests.swift` |
| WIDGET-01 | accessoryCircular rendert ohne Crash | Snapshot/Manuell | ✗ | Gerät-Checkpoint |
| WIDGET-02 | Deep Link öffnet ActivityLogSheet | Manuell (Gerät) | ✗ | Gerät-Checkpoint |
| WIDGET-03 | Familienranking zeigt Members sortiert | Unit (Mock) | ✓ | `WidgetViewTests.swift` |
| WIDGET-04 | LogActivityIntent.perform() schreibt in App Group | Unit | ✓ | `LogActivityIntentTests.swift` |
| WIDGET-04 | iOS 16 Fallback zeigt Deep Link (kein Button) | Unit (#available) | ✓ | `QuickActionWidgetTests.swift` |
| WIDGET-05 | PersonalRingsView zeigt korrekte Progress-Werte | Unit (Mock) | ✓ | `WidgetViewTests.swift` |

### Sampling Rate

- **Pro Task-Commit:** `xcodebuild build -scheme FamilyScore ... -quiet` (Build-Verifikation)
- **Pro Wave-Merge:** Full Test Suite grün
- **Phase Gate:** Gerät-Checkpoint (physisches iPhone via Sideloadly) für App Group, Widget-Rendering, Deep Links, Push-Benachrichtigung vor `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `FamilyScoreTests/RealtimeServiceTests.swift` — Unit-Tests für SYNC-01/02 (Mock-Channel)
- [ ] `FamilyScoreTests/Mocks/MockRealtimeService.swift` — Protocol + Mock
- [ ] `FamilyScoreTests/WidgetDataWriterTests.swift` — App Group schreiben/lesen
- [ ] `FamilyScoreTests/LogActivityIntentTests.swift` — AppIntent-Logic ohne Widget-Runtime
- [ ] `FamilyScoreTests/WidgetViewTests.swift` — View-Logic (sortedMembers, progress calculations)
- [ ] URL-Scheme `familyscore://` in `project.yml` prüfen/eintragen

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | Nein | Phase 2 erledigt |
| V3 Session Management | Nein | Phase 2 erledigt |
| V4 Access Control | Ja | RLS auf `device_push_tokens`; Edge Function nutzt Service-Role-Key (serverseitig, nie im iOS-Bundle) |
| V5 Input Validation | Ja | APNs Token: Hex-String-Format validieren vor DB-Insert; URL-Scheme-Parameter validieren vor Navigation |
| V6 Cryptography | Ja | APNs: JWT mit p8-Key signiert (nie im iOS-Bundle); Service-Role-Key nur in Edge Function Secrets |

### Bekannte Threat-Patterns

| Pattern | STRIDE | Standardmitigation |
|---------|--------|-------------------|
| Falscher APNs-Token für fremden User | Spoofing | `device_push_tokens` RLS: User kann nur eigene Token schreiben; keine fremden Token lesbar |
| Service-Role-Key im iOS-Bundle | Information Disclosure | Service-Role-Key nur in Supabase Edge Function Secrets (Deno Env) — NIEMALS in iOS-Code |
| Widget liest sensible Daten aus App Group | Information Disclosure | App Group ist nur für signierte Apps mit gleichem Team-ID zugänglich; keine Auth-Tokens in App Group — nur Display-Daten (Score, Name) |
| Widget-URL-Scheme-Hijacking | Spoofing | `familyscore://` ist App-spezifisch; iOS öffnet nur registrierte Apps für das Scheme |
| Massenhafte Push-Benachrichtigungen (DoS) | Denial of Service | Edge Function wird nur bei INSERT auf `activity_entries` getriggert; RLS verhindert INSERT durch Nicht-Familienmitglieder |
| Realtime-Channel ohne JWT-Auth | Spoofing/Information Disclosure | Supabase Realtime nutzt JWT aus aktiver Session; kein unauthentifizierter Channel-Zugriff möglich |
| APNs-Token im App-Group und damit Widget-lesbar | Information Disclosure | APNs-Token NIEMALS in App Group speichern — nur in Supabase DB; Widget bekommt ausschließlich Score/Display-Daten |

---

## Quellen

### Primary (HIGH confidence)
- [supabase.com/docs/reference/swift/subscribe](https://supabase.com/docs/reference/swift/subscribe) — Channel subscribe, AsyncStream-Pattern
- [supabase.com/docs/reference/swift/removechannel](https://supabase.com/docs/reference/swift/removechannel) — `removeChannel()` + `unsubscribe()` API
- [supabase.com/docs/guides/realtime/postgres-changes](https://supabase.com/docs/guides/realtime/postgres-changes) — Postgres Changes mit Filter
- [developer.apple.com/documentation/widgetkit](https://developer.apple.com/documentation/widgetkit) — WidgetKit Overview
- [developer.apple.com/documentation/widgetkit/updating-widgets-with-widgetkit-push-notifications](https://developer.apple.com/documentation/widgetkit/updating-widgets-with-widgetkit-push-notifications?changes=_3) — WidgetPushHandler, apns-push-type: widgets
- [developer.apple.com/documentation/widgetkit/widgetpushinfo](https://developer.apple.com/documentation/widgetkit/widgetpushinfo) — Push Token für Widget
- `.planning/research/ARCHITECTURE.md` — App Group Pattern, Widget Refresh Triggers, Realtime-Architektur (alle verifiziert)
- `.planning/research/PITFALLS.md` — App Group Entitlement Mismatch, 30MB Limit, Lock Screen Grayscale, Realtime Silent Disconnection (alle verifiziert)
- `FamilyScore/FamilyScoreKit/Sources/FamilyScoreKit/WidgetData.swift` — bestehender WidgetData-Struct (VERIFIED via Datei-Read)
- `FamilyScore/FamilyScoreWidgetExtension/FamilyScoreWidget.swift` — bestehende Widget-Implementierung (VERIFIED via Datei-Read)
- `FamilyScore/FamilyScore/FamilyScoreApp.swift` — XCTestConfigurationFilePath-Guard Pattern (VERIFIED via Datei-Read)

### Secondary (MEDIUM confidence)
- [developer.apple.com/documentation/widgetkit/making-a-configurable-widget](https://developer.apple.com/documentation/widgetkit/making-a-configurable-widget) — AppIntentConfiguration, Button(intent:)
- [github.com/orgs/supabase/discussions/27513](https://github.com/orgs/supabase/discussions/27513) — SUBSCRIBED/CLOSED Reconnect-Loop (bekannter Bug)
- [supabase.com/docs/guides/functions/examples/push-notifications](https://supabase.com/docs/guides/functions/examples/push-notifications) — Edge Function Webhook-Pattern
- CLAUDE.md Critical Architecture Rules — scenePhase, App Group, Supabase-SDK-Placement

### Tertiary (LOW confidence)
- WebSearch: "WidgetPushHandler implementation 2024" — Community-Berichte; bestätigen iOS 16+ Support für Widget-Push
- WebSearch: "Supabase APNs Edge Function Deno 2024" — Community-Reports zeigen gemischte Ergebnisse (A1 im Assumptions Log)

---

## Metadata

**Konfidenz-Übersicht:**
- Realtime Channel Management: HIGH — offizielle Supabase-Swift-Docs verifiziert; PITFALLS.md bestätigt scenePhase-Pattern
- WidgetKit Datenfluss (App Group + reloadAllTimelines): HIGH — ARCHITECTURE.md + Apple Docs; bereits in Phase 1 architektonisch entschieden
- AppIntents WIDGET-04: MEDIUM — Apple Docs verifiziert; perform()-in-App-Group-Muster ist ASSUMED (logische Schlussfolgerung aus 30MB Limit)
- APNs Edge Function (SYNC-03): LOW-MEDIUM — Pattern verstanden; konkrete Deno-Implementation hat Community-Reports mit Problemen; Spike empfohlen
- Widget-Push via WidgetPushHandler: MEDIUM — Apple Docs bestätigen Existenz; Complexity hoch; als Stretch Goal eingestuft

**Research-Datum:** 2026-05-17
**Gültig bis:** 2026-06-17 (supabase-swift Realtime API stabil; WidgetKit-API stabil; APNs-Detail ggf. früher prüfen)
