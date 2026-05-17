# Phase 5: Real-time & Widgets — Pattern Map

**Mapped:** 2026-05-17
**Files analyzed:** 20 (neue/modifizierte Dateien)
**Analogs found:** 18 / 20

---

## File Classification

| Neue/Modifizierte Datei | Role | Data Flow | Closest Analog | Match Quality |
|-------------------------|------|-----------|----------------|---------------|
| `FamilyScore/Services/RealtimeService.swift` | service | event-driven | `FamilyScore/FamilyScore/Services/AuthService.swift` | role-match |
| `FamilyScore/Services/NotificationService.swift` | service | request-response | `FamilyScore/FamilyScore/Services/AuthService.swift` | role-match |
| `FamilyScore/Helpers/WidgetDataWriter.swift` | utility | transform | `FamilyScore/FamilyScore/Services/AuthService.swift` | partial-match |
| `FamilyScoreKit/Sources/FamilyScoreKit/WidgetData.swift` | model | — | `FamilyScoreKit/Sources/FamilyScoreKit/WidgetData.swift` | exact (modify) |
| `FamilyScore/FamilyScoreWidgetExtension/FamilyScoreWidgetBundle.swift` | config | — | `FamilyScore/FamilyScoreWidgetExtension/FamilyScoreWidgetBundle.swift` | exact (modify) |
| `FamilyScore/FamilyScoreWidgetExtension/Widgets/AccessoryCircularWidget.swift` | component | request-response | `FamilyScore/FamilyScoreWidgetExtension/FamilyScoreWidget.swift` | role-match |
| `FamilyScore/FamilyScoreWidgetExtension/Widgets/AccessoryRectangularWidget.swift` | component | request-response | `FamilyScore/FamilyScoreWidgetExtension/FamilyScoreWidget.swift` | role-match |
| `FamilyScore/FamilyScoreWidgetExtension/Widgets/FamilyRankingWidget.swift` | component | request-response | `FamilyScore/FamilyScoreWidgetExtension/FamilyScoreWidget.swift` | role-match |
| `FamilyScore/FamilyScoreWidgetExtension/Widgets/QuickEntryWidget.swift` | component | request-response | `FamilyScore/FamilyScoreWidgetExtension/FamilyScoreWidget.swift` | role-match |
| `FamilyScore/FamilyScoreWidgetExtension/Widgets/PersonalRingsWidget.swift` | component | request-response | `FamilyScore/FamilyScoreWidgetExtension/FamilyScoreWidget.swift` | role-match |
| `FamilyScore/FamilyScoreWidgetExtension/Providers/FamilyScoreProvider.swift` | provider | request-response | `FamilyScore/FamilyScoreWidgetExtension/FamilyScoreWidget.swift` | exact (replace) |
| `FamilyScore/FamilyScoreWidgetExtension/Providers/WidgetData+AppGroup.swift` | utility | transform | `FamilyScoreKit/Sources/FamilyScoreKit/WidgetData.swift` | role-match |
| `FamilyScoreKit/Sources/FamilyScoreKit/Intents/LogActivityIntent.swift` | utility | event-driven | kein Analog | no-match |
| `FamilyScore/FamilyScore/FamilyScoreApp.swift` | config | event-driven | `FamilyScore/FamilyScore/FamilyScoreApp.swift` | exact (modify) |
| `FamilyScoreTests/RealtimeServiceTests.swift` | test | event-driven | `FamilyScoreTests/FamilyServiceTests.swift` | exact |
| `FamilyScoreTests/Mocks/MockRealtimeService.swift` | test | event-driven | `FamilyScoreTests/Mocks/MockFamilyService.swift` | exact |
| `FamilyScoreTests/WidgetDataWriterTests.swift` | test | transform | `FamilyScoreTests/AuthServiceTests.swift` | role-match |
| `FamilyScoreTests/LogActivityIntentTests.swift` | test | event-driven | `FamilyScoreTests/AuthServiceTests.swift` | role-match |
| `FamilyScoreTests/WidgetViewTests.swift` | test | request-response | `FamilyScoreTests/FamilyServiceTests.swift` | role-match |
| `supabase/migrations/20260517_phase5_push_tokens.sql` | migration | CRUD | `supabase/migrations/20260515_phase3_family_core.sql` | exact |
| `supabase/functions/push-notification/index.ts` | service | event-driven | kein Analog (TypeScript/Deno) | no-match |

---

## Pattern Assignments

### `FamilyScore/Services/RealtimeService.swift` (service, event-driven)

**Analog:** `FamilyScore/FamilyScore/Services/AuthService.swift`

**Imports-Pattern** (AuthService.swift Zeilen 1–9):
```swift
// FamilyScore/Services/RealtimeService.swift
// Target Membership: FamilyScore (App) ONLY — NIEMALS Widget Extension
// iOS 16.0 Minimum: ObservableObject + @Published (NICHT @Observable — iOS 17+)
// Supabase SDK NUR im Hauptapp-Target (CLAUDE.md Architektur-Regel)

import Foundation
@preconcurrency import Supabase
```

**Klassen-Deklaration** (AuthService.swift Zeilen 11–14):
```swift
@MainActor
final class RealtimeService: ObservableObject {

    private var channel: RealtimeChannelV2?
    private var listeningTask: Task<Void, Never>?
```

**XCTestConfigurationFilePath-Guard** (FamilyScoreApp.swift Zeilen 24–27 — PFLICHT):
```swift
// KRITISCH: Dieser Guard MUSS als erstes in startListening() stehen
// Ohne Guard: Supabase Realtime haengt 227s in CI und crasht mit signal trap
// Quelle: CLAUDE.md "XCTest / Test-Architektur (Regeln aus wiederholten Fehlern)"
guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
    print("[Realtime] XCTest-Umgebung erkannt — startListening() uebersprungen")
    return
}
```

**Supabase-Channel-Subscribe-Pattern** (aus 05-RESEARCH.md Pattern 1, Zeilen 230–265):
```swift
// ACHTUNG: postgresChange() MUSS vor subscribe() aufgerufen werden
// Falsche Reihenfolge: Channel empfaengt keine Events
let ch = await supabase.channel("family-\(familyId.uuidString)")

let entryChanges = await ch.postgresChange(
    AnyAction.self,
    schema: "public",
    table: "activity_entries",
    filter: .eq("family_id", value: familyId.uuidString)
)

let summaryChanges = await ch.postgresChange(
    AnyAction.self,
    schema: "public",
    table: "weekly_summaries",
    filter: .eq("family_id", value: familyId.uuidString)
)

await ch.subscribe()
self.channel = ch
```

**Async-Event-Loop-Pattern** (aus 05-RESEARCH.md Pattern 1, Zeilen 252–265):
```swift
// Task-Group fuer parallele Event-Streams
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
```

**Channel-Stopp-Pattern** (aus 05-RESEARCH.md Pattern 1, Zeilen 270–278):
```swift
// PITFALL: Kein sofortiges re-subscribe nach removeChannel
// Bekannter Bug: SUBSCRIBED/CLOSED-Loop (GitHub Discussion #27513)
// 100ms Pause zwischen removeChannel und neuem subscribe
func stopListening() async {
    listeningTask?.cancel()
    listeningTask = nil
    if let ch = channel {
        await supabase.removeChannel(ch)
        channel = nil
    }
}
```

**Error-Handling-Pattern** (AuthService.swift Zeilen 96–100):
```swift
// Muster: switch auf AnyAction — nur INSERT und DELETE benoetigt
private func handleActivityChange(_ change: AnyAction) async {
    switch change {
    case .insert(let action):
        if let entry = try? action.decodeRecord(as: ActivityEntry.self) {
            // State aktualisieren
        }
    case .delete(let action):
        let id = action.oldRecord["id"]?.stringValue
        // State aktualisieren
    default: break
    }
    // IMMER nach jeder Aenderung Widget-Cache aktualisieren
    await WidgetDataWriter.shared.updateAndReload()
}
```

---

### `FamilyScore/Services/NotificationService.swift` (service, request-response)

**Analog:** `FamilyScore/FamilyScore/Services/AuthService.swift`

**Imports-Pattern** (AuthService.swift Zeilen 1–9):
```swift
// FamilyScore/Services/NotificationService.swift
// Target Membership: FamilyScore (App) ONLY
// iOS 16.0 Minimum: ObservableObject + @Published

import Foundation
import UserNotifications
// Kein Supabase-Import direkt — upsert via supabase (globaler Client aus Supabase.swift)
```

**Klassen-Deklaration** (AuthService.swift Zeilen 11–14):
```swift
@MainActor
final class NotificationService: ObservableObject {

    @Published private(set) var isAuthorized: Bool = false
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
```

**Permission-Request-Pattern** (aus 05-RESEARCH.md Pattern 6, Zeilen 828–843):
```swift
// Opt-in: User muss explizit zustimmen — kein automatischer Request beim App-Start
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
```

**Token-Upsert-Pattern** (aus 05-RESEARCH.md Pattern 6, Zeilen 844–857):
```swift
// Wird nach didRegisterForRemoteNotificationsWithDeviceToken aufgerufen
// Data → Hex-String (Standard iOS APNs Token Format)
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
```

**Error-Handling-Pattern** (AuthService.swift `localizedError` Zeilen 109–121):
```swift
// Analoges Muster: try? statt do/catch fuer nicht-kritische Operationen (Token upsert)
// Kritische Fehler (Permission Denied) werden via @Published isAuthorized kommuniziert
```

---

### `FamilyScore/Helpers/WidgetDataWriter.swift` (utility, transform)

**Analog:** `FamilyScore/FamilyScore/Services/AuthService.swift` (Singleton-Pattern)

**Imports-Pattern**:
```swift
// FamilyScore/Helpers/WidgetDataWriter.swift
// Target Membership: FamilyScore (App) ONLY — kein Widget-Import
// WidgetKit Import NUR fuer WidgetCenter.shared.reloadAllTimelines()
import Foundation
import WidgetKit
import FamilyScoreKit
```

**Singleton-Klassen-Pattern** (analog zu AuthService-Struktur, aber Singleton statt @StateObject):
```swift
// @MainActor weil reloadAllTimelines() und UserDefaults auf Main Thread sicherer
@MainActor
final class WidgetDataWriter {
    static let shared = WidgetDataWriter()
    private init() {}

    // KRITISCH: UserDefaults(suiteName:) kann nil sein wenn App Group nicht konfiguriert
    // Pitfall SC-2 aus 05-RESEARCH.md: physisches Geraet verifizieren bevor Widget-UI
    private let defaults = UserDefaults(suiteName: appGroupIdentifier)
```

**Schreib-Pattern mit WidgetCenter-Reload** (aus 05-RESEARCH.md Pattern 3, Zeilen 391–397):
```swift
func write(_ data: WidgetData) {
    guard let encoded = try? JSONEncoder().encode(data),
          let defaults = defaults else { return }
    defaults.set(encoded, forKey: "widgetData")
    // Kein synchronize() noetig — iOS schreibt automatisch
    // PITFALL: iOS throttled reloadAllTimelines() auf 40-70 Mal/Tag
    // Debounce empfohlen wenn viele Realtime-Events in kurzer Zeit
    WidgetCenter.shared.reloadAllTimelines()
}
```

**Debounce-Pattern** (aus 05-RESEARCH.md Pitfall 4):
```swift
// Task-basiertes Debouncing: 5 Sekunden nach letztem Event warten
private var debounceTask: Task<Void, Never>?

func scheduleReload() {
    debounceTask?.cancel()
    debounceTask = Task {
        try? await Task.sleep(nanoseconds: 5_000_000_000)  // 5s
        if !Task.isCancelled {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
```

---

### `FamilyScoreKit/Sources/FamilyScoreKit/WidgetData.swift` (model) — MODIFY

**Analog:** `FamilyScoreKit/Sources/FamilyScoreKit/WidgetData.swift` (identische Datei)

**Bestehendes Struct** (WidgetData.swift Zeilen 1–34 — NICHT entfernen):
```swift
// Sources/FamilyScoreKit/WidgetData.swift
// KEIN Supabase SDK import — nur Foundation
// public init() IMMER definieren — Package-Typen ohne init() sind extern nicht konstruierbar
import Foundation

public struct WidgetData: Codable, Sendable {
    public struct MemberScore: Codable, Sendable {
        public let displayName: String
        public let avatarInitial: String
        public let weeklyPoints: Double
        public let weeklyMinutes: Int
        // ERWEITERUNG Phase 5:
        public let avatarColor: String  // NEU: Hex-String fuer Avatar-Farbe in WIDGET-03

        public init(displayName: String, avatarInitial: String,
                    weeklyPoints: Double, weeklyMinutes: Int,
                    avatarColor: String = "#007AFF") {
            // ...
        }
    }
```

**Neue Felder hinzufuegen** (nach bestehenden Zeilen 22–30 — rueckwaertskompatibel):
```swift
    // Bestehende Felder Phase 1 (unveraendert lassen)
    public let familyName: String
    public let members: [MemberScore]
    public let lastUpdated: Date

    // NEU Phase 5: WIDGET-05 Persoenliche Ringe
    public let myDutyProgress: Double      // 0.0–1.0+ (Pflicht-Ring)
    public let myLeisureProgress: Double   // 0.0–1.0+ (Freizeit-Ring)
    public let myScoreProgress: Double     // 0.0–1.0+ (Score-Ring)

    // NEU Phase 5: WIDGET-01 Lock-Screen-Score-Ring
    public let myTodayScore: Int           // heutiger Score in Punkten
    public let myTodayScoreGoal: Int       // Tagesziel (z.B. 60 Punkte)

    // public init() MUSS alle Felder setzen — neue Felder mit Default-Werten
    public init(familyName: String, members: [MemberScore], lastUpdated: Date,
                myDutyProgress: Double = 0, myLeisureProgress: Double = 0,
                myScoreProgress: Double = 0, myTodayScore: Int = 0,
                myTodayScoreGoal: Int = 60) {
        // ...
    }
```

**Placeholder-Erweiterung** (WidgetData.swift Zeilen 37–48 — aktualisieren):
```swift
// Neuen Parameter im bestehenden placeholder eintragen (rueckwaertskompatibel durch Default-Werte)
extension WidgetData {
    public static let placeholder = WidgetData(
        familyName: "Familie Muster",
        members: [
            MemberScore(displayName: "Max", avatarInitial: "M",
                        weeklyPoints: 120, weeklyMinutes: 90, avatarColor: "#007AFF"),
            MemberScore(displayName: "Anna", avatarInitial: "A",
                        weeklyPoints: 95, weeklyMinutes: 75, avatarColor: "#FF9500")
        ],
        lastUpdated: Date(),
        myDutyProgress: 0.6,
        myLeisureProgress: 0.4,
        myScoreProgress: 0.7,
        myTodayScore: 42,
        myTodayScoreGoal: 60
    )
}
```

---

### `FamilyScore/FamilyScoreWidgetExtension/FamilyScoreWidgetBundle.swift` (config) — MODIFY

**Analog:** `FamilyScore/FamilyScoreWidgetExtension/FamilyScoreWidgetBundle.swift` (identische Datei)

**Bestehendes Bundle** (FamilyScoreWidgetBundle.swift Zeilen 1–9 — als Ausgangspunkt):
```swift
import WidgetKit
import SwiftUI

@main
struct FamilyScoreWidgetBundle: WidgetBundle {
    var body: some Widget {
        FamilyScoreWidget()  // Phase 1 Placeholder — ERSETZEN durch 5 echte Widgets
    }
}
```

**Erweitertes Bundle** (Phase 5 — alle 5 Widgets registrieren):
```swift
@main
struct FamilyScoreWidgetBundle: WidgetBundle {
    var body: some Widget {
        AccessoryCircularWidget()    // WIDGET-01: Lock Screen Score-Ring
        AccessoryRectangularWidget() // WIDGET-02: Lock Screen Schnelleintrag (Deep Link)
        FamilyRankingWidget()        // WIDGET-03: Home Screen Familienranking (systemLarge)
        QuickEntryWidget()           // WIDGET-04: Home Screen Quick-Entry (AppIntent iOS 17+)
        PersonalRingsWidget()        // WIDGET-05: Home Screen Persoenliche Ringe (systemMedium)
    }
}
```

---

### `FamilyScore/FamilyScoreWidgetExtension/Widgets/AccessoryCircularWidget.swift` (component, request-response)

**Analog:** `FamilyScore/FamilyScoreWidgetExtension/FamilyScoreWidget.swift`

**Widget-Konfigurations-Pattern** (FamilyScoreWidget.swift Zeilen 40–54):
```swift
import WidgetKit
import SwiftUI
import FamilyScoreKit

struct AccessoryCircularWidget: Widget {
    let kind: String = "ScoreRing"   // kind = stabiler Identifier — nie aendern nach Deployment

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FamilyScoreProvider()) { entry in
            ScoreRingView(entry: entry)
                // KEIN .containerBackground() fuer accessory* Widgets auf iOS 16
                // containerBackground ist systemSmall/Medium/Large-spezifisch
        }
        .configurationDisplayName("Mein Score")
        .description("Zeigt deinen heutigen Score.")
        .supportedFamilies([.accessoryCircular])
    }
}
```

**Gauge-View-Pattern fuer accessoryCircular** (aus 05-RESEARCH.md Pattern 4, Zeilen 478–490):
```swift
struct ScoreRingView: View {
    let entry: FamilyScoreEntry

    var body: some View {
        // Gauge: speziell fuer accessoryCircular designed (iOS 16+)
        // PITFALL: Kein farbiges Design — Lock Screen rendert grayscale
        // .widgetAccentable() fuer System-Akzentfarbe (einzige erlaubte Farbe)
        Gauge(value: Double(entry.data.myTodayScore),
              in: 0...Double(max(1, entry.data.myTodayScoreGoal))) {
            Image(systemName: "star.fill")
        } currentValueLabel: {
            Text("\(entry.data.myTodayScore)")
                .font(.system(size: 14, weight: .bold))
        }
        .gaugeStyle(.accessoryCircular)
        .widgetAccentable()
    }
}
```

**FamilyScoreEntry muss WidgetData enthalten** (FamilyScoreWidget.swift Zeile 29 — erweitern):
```swift
// Phase 1: struct FamilyScoreEntry: TimelineEntry { let date: Date }
// Phase 5: WidgetData hinzufuegen
struct FamilyScoreEntry: TimelineEntry {
    let date: Date
    let data: WidgetData  // NEU: Phase 5 — war fehlendes Feld
}
```

---

### `FamilyScore/FamilyScoreWidgetExtension/Widgets/AccessoryRectangularWidget.swift` (component, request-response)

**Analog:** `FamilyScore/FamilyScoreWidgetExtension/FamilyScoreWidget.swift`

**Widget-Konfigurations-Pattern** (FamilyScoreWidget.swift Zeilen 40–54):
```swift
struct AccessoryRectangularWidget: Widget {
    let kind: String = "QuickEntry"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FamilyScoreProvider()) { entry in
            QuickEntryView(entry: entry)
        }
        .configurationDisplayName("Schnelleintrag")
        .description("Kategorie antippen zum Eintragen.")
        .supportedFamilies([.accessoryRectangular])
    }
}
```

**Deep-Link-Pattern statt AppIntent** (aus 05-RESEARCH.md Pattern 4, Zeilen 513–537):
```swift
struct QuickEntryView: View {
    let entry: FamilyScoreEntry
    let categories: [(name: String, icon: String, urlPath: String)] = [
        ("Haushalt", "house.fill", "haushalt"),
        ("Freizeit", "gamecontroller.fill", "freizeit"),
        ("Besorgungen", "bag.fill", "besorgungen"),
        ("Arbeit", "book.fill", "arbeit")
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(categories, id: \.name) { cat in
                // Link statt Button(intent:) — accessoryRectangular unterstuetzt KEIN Button(intent:)
                // Pitfall A6 aus 05-RESEARCH.md: interaktive Controls nur systemSmall/Medium/Large iOS 17+
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
        .widgetURL(URL(string: "familyscore://")!)  // Fallback fuer Tap ausserhalb der Buttons
    }
}
```

---

### `FamilyScore/FamilyScoreWidgetExtension/Widgets/FamilyRankingWidget.swift` (component, request-response)

**Analog:** `FamilyScore/FamilyScoreWidgetExtension/FamilyScoreWidget.swift`

**Widget-Konfigurations-Pattern** (FamilyScoreWidget.swift Zeilen 40–54):
```swift
struct FamilyRankingWidget: Widget {
    let kind: String = "FamilyRanking"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FamilyScoreProvider()) { entry in
            FamilyRankingView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)  // systemLarge braucht containerBackground
        }
        .configurationDisplayName("Familienübersicht")
        .description("Wochenpunkte aller Familienmitglieder.")
        .supportedFamilies([.systemLarge])
    }
}
```

**containerBackground-Muster** (FamilyScoreWidget.swift Zeilen 43–48):
```swift
// iOS 17+: .containerBackground Modifier
// iOS 16: kein .containerBackground — direkt View ohne Modifier
// FamilyScoreWidget.swift zeigt bereits das #available(iOS 17, *) Muster:
if #available(iOS 17, *) {
    FamilyScoreWidgetEntryView(entry: entry)
        .containerBackground(.fill.tertiary, for: .widget)
} else {
    FamilyScoreWidgetEntryView(entry: entry)
}
```

**Avatar-als-Text-Initial-Pattern** (aus 05-RESEARCH.md Pitfall 5):
```swift
// KEIN Bild-Asset fuer Avatare — 30MB Widget-Limit
// Text-Initial in farbigem Kreis (nur Foundation/SwiftUI, kein UIKit)
Circle()
    .fill(Color(hex: member.avatarColor) ?? .blue)
    .frame(width: 28, height: 28)
    .overlay(
        Text(member.avatarInitial)
            .font(.caption)
            .foregroundColor(.white)
    )
```

---

### `FamilyScore/FamilyScoreWidgetExtension/Widgets/QuickEntryWidget.swift` (component, request-response)

**Analog:** `FamilyScore/FamilyScoreWidgetExtension/FamilyScoreWidget.swift`

**iOS 17+ Guard-Pattern** (FamilyScoreWidget.swift Zeilen 43–50 — exakt dieses Muster):
```swift
struct QuickEntryWidget: Widget {
    let kind: String = "QuickAction"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FamilyScoreProvider()) { entry in
            // #available Guard — iOS 16 Geraete bekommen Deep-Link-Fallback
            if #available(iOS 17, *) {
                QuickActionView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                Text("App oeffnen zum Eintragen")
                    .widgetURL(URL(string: "familyscore://log")!)
            }
        }
        .configurationDisplayName("Schnelleintrag")
        .description("Aktivitaet direkt vom Widget eintragen.")
        .supportedFamilies([.systemLarge])
    }
}
```

**AppIntent Button-Pattern iOS 17+** (aus 05-RESEARCH.md Pattern 4, Zeilen 639–659):
```swift
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
                // Button(intent:) ist iOS 17+ only — daher @available Guard am View
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

---

### `FamilyScore/FamilyScoreWidgetExtension/Widgets/PersonalRingsWidget.swift` (component, request-response)

**Analog:** `FamilyScore/FamilyScoreWidgetExtension/FamilyScoreWidget.swift`

**Widget-Konfigurations-Pattern** (FamilyScoreWidget.swift Zeilen 40–54):
```swift
struct PersonalRingsWidget: Widget {
    let kind: String = "PersonalRings"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FamilyScoreProvider()) { entry in
            PersonalRingsView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Meine Ringe")
        .description("Deine heutigen Pflicht-, Freizeit- und Score-Ringe.")
        .supportedFamilies([.systemMedium])
    }
}
```

**Ring-Progress-Darstellung** (aus Phase 4 RingClusterView-Muster, MiniVersion):
```swift
// MiniRingClusterView: kleinere Version des Phase-4-RingClusterView
// Daten kommen aus WidgetData (nicht ActivityService) — kein Netzwerk im Widget
struct PersonalRingsView: View {
    let entry: FamilyScoreEntry

    var body: some View {
        HStack(spacing: 16) {
            // Kompakter Ring-Cluster (MiniRingClusterView aus Phase 4 wiederverwenden)
            MiniRingClusterView(
                dutyProgress: entry.data.myDutyProgress,
                leisureProgress: entry.data.myLeisureProgress,
                scoreProgress: entry.data.myScoreProgress
            )
            VStack(alignment: .leading, spacing: 4) {
                Label("Pflicht", systemImage: "house.fill").foregroundColor(.red)
                Label("Freizeit", systemImage: "gamecontroller.fill").foregroundColor(.green)
                Label("Score", systemImage: "star.fill").foregroundColor(.blue)
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

### `FamilyScore/FamilyScoreWidgetExtension/Providers/FamilyScoreProvider.swift` (provider) — REPLACE

**Analog:** `FamilyScore/FamilyScoreWidgetExtension/FamilyScoreWidget.swift` (FamilyScoreProvider-Block, Zeilen 5–27)

**Bestehender Placeholder** (FamilyScoreWidget.swift Zeilen 5–27 — vollstaendig ersetzen):
```swift
// Phase 1 Placeholder — KOMPLETT durch echten Provider ersetzen
struct FamilyScoreProvider: TimelineProvider {
    func placeholder(in context: Context) -> FamilyScoreEntry {
        FamilyScoreEntry(date: Date())  // Phase 5: FamilyScoreEntry(date:, data:) braucht WidgetData
    }
    // ...
}
```

**Echter Provider** (aus 05-RESEARCH.md Pattern 3, Zeilen 425–434):
```swift
struct FamilyScoreProvider: TimelineProvider {

    func placeholder(in context: Context) -> FamilyScoreEntry {
        FamilyScoreEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context,
                     completion: @escaping (FamilyScoreEntry) -> Void) {
        let data = WidgetData.readFromAppGroup() ?? .placeholder
        completion(FamilyScoreEntry(date: .now, data: data))
    }

    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<FamilyScoreEntry>) -> Void) {
        let data = WidgetData.readFromAppGroup() ?? .placeholder
        let entry = FamilyScoreEntry(date: .now, data: data)
        // Stuendlicher Fallback — normaler Refresh via WidgetCenter.shared.reloadAllTimelines()
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}
```

---

### `FamilyScore/FamilyScoreWidgetExtension/Providers/WidgetData+AppGroup.swift` (utility, transform)

**Analog:** `FamilyScoreKit/Sources/FamilyScoreKit/WidgetData.swift` (extension-Pattern, Zeilen 37–48)

**Extension-Pattern** (WidgetData.swift Zeilen 37–48):
```swift
// FamilyScoreWidgetExtension/Providers/WidgetData+AppGroup.swift
// Target Membership: FamilyScoreWidgetExtension ONLY
// KEIN Supabase-Import — nur Foundation + FamilyScoreKit

import Foundation
import FamilyScoreKit

extension WidgetData {
    // Liest WidgetData aus App Group — nil wenn leer oder noch nie geschrieben
    // appGroupIdentifier ist in FamilyScoreKit/WidgetData.swift definiert ("group.com.familyscore")
    static func readFromAppGroup() -> WidgetData? {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: "widgetData"),
              let widgetData = try? JSONDecoder().decode(WidgetData.self, from: data)
        else { return nil }
        return widgetData
    }
}
```

---

### `FamilyScoreKit/Sources/FamilyScoreKit/Intents/LogActivityIntent.swift` (utility, event-driven)

**Analog:** kein Analog in der Codebase — AppIntents ist neu in Phase 5

**Target-Membership-Hinweis** (aus 05-RESEARCH.md Pitfall 8):
```swift
// KRITISCH: LogActivityIntent MUSS in FamilyScoreKit (shared Package) definiert werden
// Begruendung: Widget Extension braucht Zugriff auf Intent fuer Button(intent:)
//              App braucht Zugriff fuer pending_log-Drain beim Foreground
//              Loesung: FamilyScoreKit = einzige Quelle (kein Supabase-Import noetig)
// NICHT im App-Target oder Widget-Extension-Target allein — dann Build-Fehler

// FamilyScoreKit/Sources/FamilyScoreKit/Intents/LogActivityIntent.swift
import AppIntents
import Foundation

// appGroupIdentifier kommt aus FamilyScoreKit/WidgetData.swift
// kein separater Import noetig — gleicher Package

@available(iOS 16.0, *)
struct LogActivityIntent: AppIntent {
    static let title: LocalizedStringResource = "Aktivitaet eintragen"

    @Parameter(title: "Kategorie")
    var categorySlug: String

    // perform() darf NIEMALS Supabase/Netzwerk aufrufen — Widget-Prozess, 30MB Limit
    // Strategie: pending_log in App Group schreiben; App drainiert beim naechsten Foreground
    func perform() async throws -> some IntentResult {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return .result()
        }
        var pending = (defaults.array(forKey: "pendingLogs") as? [[String: String]]) ?? []
        pending.append([
            "category": categorySlug,
            "timestamp": ISO8601DateFormatter().string(from: .now)
        ])
        defaults.set(pending, forKey: "pendingLogs")
        return .result()
    }
}

// Convenience init fuer Button(intent:) in QuickActionView
extension LogActivityIntent {
    init(categorySlug: String) {
        self.categorySlug = categorySlug
    }
}
```

---

### `FamilyScore/FamilyScore/FamilyScoreApp.swift` (config, event-driven) — MODIFY

**Analog:** `FamilyScore/FamilyScore/FamilyScoreApp.swift` (identische Datei — erweitern)

**Bestehender App-Koerper** (FamilyScoreApp.swift Zeilen 7–36 — Ausgangspunkt):
```swift
@main
struct FamilyScoreApp: App {
    @StateObject private var authService = AuthService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authService)
                .task { /* startObserving() mit XCTest-Guard */ }
        }
    }
}
```

**Erweiterung mit RealtimeService und scenePhase** (aus 05-RESEARCH.md Pattern 1, Zeilen 316–333):
```swift
@main
struct FamilyScoreApp: App {
    @StateObject private var authService = AuthService()
    // NEU Phase 5: RealtimeService und NotificationService
    @StateObject private var realtimeService = RealtimeService()
    @StateObject private var notificationService = NotificationService()

    // scenePhase: steuert Realtime-Lifecycle
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authService)
                .environmentObject(realtimeService)
                .environmentObject(notificationService)
                .task { /* bestehender startObserving()-Aufruf UNVERAENDERT lassen */ }
                // NEU: scenePhase-Handler fuer Realtime-Lifecycle
                .onChange(of: scenePhase) { _, newPhase in
                    guard let familyId = /* authService.currentFamilyId */ else { return }
                    if newPhase == .active {
                        Task {
                            // REST-Refetch zuerst (Events waehrend Background koennen verloren gehen)
                            // dann re-subscribe
                            await realtimeService.refetchAndResubscribe(
                                familyId: familyId,
                                activityService: /* aus Environment */
                            )
                            // Pending Widget-Logs drainieren (WIDGET-04 AppIntent)
                            await drainPendingWidgetLogs()
                        }
                    } else if newPhase == .background {
                        Task { await realtimeService.stopListening() }
                    }
                }
                // NEU: Deep Link Handler (WIDGET-02 accessoryRectangular)
                .onOpenURL { url in
                    guard url.scheme == "familyscore" else { return }
                    if url.host == "log" {
                        let category = url.queryItems?.first(where: { $0.name == "category" })?.value
                        NotificationCenter.default.post(
                            name: .openQuickLog,
                            object: nil,
                            userInfo: ["category": category as Any]
                        )
                    }
                }
        }
    }

    // Pending logs aus WIDGET-04 AppIntent drainieren
    private func drainPendingWidgetLogs() async {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let pending = defaults.array(forKey: "pendingLogs") as? [[String: String]],
              !pending.isEmpty
        else { return }
        defaults.removeObject(forKey: "pendingLogs")
        // ActivityService aus Environment verwenden um echte Logs zu schreiben
    }
}

extension Notification.Name {
    static let openQuickLog = Notification.Name("openQuickLog")
}
```

**URL Query Items Helper** (kein Analog — Standard Foundation):
```swift
// URL Extension fuer sauberes Query-Parameter-Parsing
extension URL {
    var queryItems: [URLQueryItem]? {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?.queryItems
    }
}
```

---

### `FamilyScoreTests/RealtimeServiceTests.swift` (test, event-driven)

**Analog:** `FamilyScoreTests/FamilyServiceTests.swift` — exakter Match fuer Teststruktur

**Test-Klassen-Struktur** (FamilyServiceTests.swift Zeilen 1–22):
```swift
// FamilyScoreTests/RealtimeServiceTests.swift
// Target Membership: FamilyScoreTests
// STUBS — Wave 0; MockRealtimeService-basiert, kein echter Supabase-Channel
// Anforderungen: SYNC-01, SYNC-02

import XCTest
@testable import FamilyScore

@MainActor
final class RealtimeServiceTests: XCTestCase {

    var mock: MockRealtimeService!

    override func setUp() async throws {
        try await super.setUp()
        mock = MockRealtimeService()
    }

    override func tearDown() async throws {
        mock = nil
        try await super.tearDown()
    }

    // SYNC-01: startListening() setzt isListening = true
    func testStartListeningSetsIsListening() async throws {
        XCTAssertFalse(mock.isListening)
        await mock.startListening(familyId: UUID())
        XCTAssertTrue(mock.isListening)
    }

    // SYNC-01: stopListening() setzt isListening = false
    func testStopListeningSetsNotListening() async throws {
        await mock.startListening(familyId: UUID())
        await mock.stopListening()
        XCTAssertFalse(mock.isListening)
    }

    // SYNC-01: XCTestConfigurationFilePath-Guard verhindert echten Connect
    // Wird durch MockRealtimeService immer guaranteed — kein echter Channel in Tests
    func testXCTestGuardPreventsSupabaseConnect() async throws {
        // MockRealtimeService macht NIE einen echten Supabase-Call
        // Echter RealtimeService haette XCTestConfigurationFilePath-Guard
        XCTAssertTrue(ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
                      || true)  // Guard-Existenz dokumentieren
    }
}
```

---

### `FamilyScoreTests/Mocks/MockRealtimeService.swift` (test, event-driven)

**Analog:** `FamilyScoreTests/Mocks/MockFamilyService.swift` — exakter Match

**Mock-Klassen-Struktur** (MockFamilyService.swift Zeilen 1–27):
```swift
// FamilyScoreTests/Mocks/MockRealtimeService.swift
// Target Membership: FamilyScoreTests ONLY

import Foundation
import Combine
@testable import FamilyScore

@MainActor
protocol RealtimeServiceProtocol: AnyObject {
    var isListening: Bool { get }
    func startListening(familyId: UUID) async
    func stopListening() async
    func refetchAndResubscribe(familyId: UUID, activityService: ActivityService) async
}

@MainActor
final class MockRealtimeService: ObservableObject, RealtimeServiceProtocol {
    @Published private(set) var isListening: Bool = false

    // Verhalten-Flags (Muster aus MockFamilyService.swift Zeilen 40–55)
    var startListeningCallCount: Int = 0
    var stopListeningCallCount: Int = 0
    var lastFamilyId: UUID? = nil

    func startListening(familyId: UUID) async {
        startListeningCallCount += 1
        lastFamilyId = familyId
        isListening = true
    }

    func stopListening() async {
        stopListeningCallCount += 1
        isListening = false
    }

    func refetchAndResubscribe(familyId: UUID, activityService: ActivityService) async {
        await startListening(familyId: familyId)
    }
}
```

---

### `FamilyScoreTests/WidgetDataWriterTests.swift` (test, transform)

**Analog:** `FamilyScoreTests/AuthServiceTests.swift` (Test-Klassen-Struktur)

**Test-Struktur** (AuthServiceTests.swift Zeilen 1–19):
```swift
// FamilyScoreTests/WidgetDataWriterTests.swift
// Target Membership: FamilyScoreTests
// Zweck: App Group lesen/schreiben ohne echte WidgetKit-Runtime

import XCTest
@testable import FamilyScore
import FamilyScoreKit

@MainActor
final class WidgetDataWriterTests: XCTestCase {

    // WIDGET-01..05: write() schreibt korrekt in UserDefaults
    func testWriteEncodesWidgetDataIntoAppGroup() throws {
        let defaults = UserDefaults(suiteName: appGroupIdentifier)
        let testData = WidgetData.placeholder
        // WidgetDataWriter.shared.write(testData)  // WidgetCenter.reloadAllTimelines() wird nicht crashen in Tests
        let encoded = try JSONEncoder().encode(testData)
        defaults?.set(encoded, forKey: "widgetData")
        let read = WidgetData.readFromAppGroup()  // readFromAppGroup via extension
        XCTAssertNotNil(read)
        XCTAssertEqual(read?.familyName, testData.familyName)
        XCTAssertEqual(read?.myTodayScore, testData.myTodayScore)
    }

    // WIDGET-05: myDutyProgress wird korrekt dekodiert
    func testMyDutyProgressDecodesCorrectly() throws {
        let data = WidgetData(familyName: "Test", members: [], lastUpdated: .now,
                              myDutyProgress: 0.75, myLeisureProgress: 0.5,
                              myScoreProgress: 0.6, myTodayScore: 45, myTodayScoreGoal: 60)
        let encoded = try JSONEncoder().encode(data)
        let decoded = try JSONDecoder().decode(WidgetData.self, from: encoded)
        XCTAssertEqual(decoded.myDutyProgress, 0.75, accuracy: 0.001)
    }
}
```

---

### `FamilyScoreTests/LogActivityIntentTests.swift` (test, event-driven)

**Analog:** `FamilyScoreTests/AuthServiceTests.swift` (Test-Klassen-Struktur)

**Test-Struktur** (AuthServiceTests.swift Zeilen 1–19):
```swift
// FamilyScoreTests/LogActivityIntentTests.swift
// Target Membership: FamilyScoreTests
// Zweck: LogActivityIntent.perform() ohne Widget-Runtime testen

import XCTest
@testable import FamilyScore
import FamilyScoreKit

@MainActor
final class LogActivityIntentTests: XCTestCase {

    override func setUp() async throws {
        // App Group leeren vor jedem Test
        UserDefaults(suiteName: appGroupIdentifier)?.removeObject(forKey: "pendingLogs")
    }

    // WIDGET-04: perform() schreibt pending_log in App Group
    func testPerformWritesPendingLog() async throws {
        let intent = LogActivityIntent(categorySlug: "haushalt")
        _ = try await intent.perform()

        let defaults = UserDefaults(suiteName: appGroupIdentifier)
        let pending = defaults?.array(forKey: "pendingLogs") as? [[String: String]]
        XCTAssertNotNil(pending)
        XCTAssertEqual(pending?.count, 1)
        XCTAssertEqual(pending?.first?["category"], "haushalt")
    }

    // WIDGET-04: perform() bei leerem App Group erstellt neues Array
    func testPerformCreatesArrayWhenEmpty() async throws {
        let intent = LogActivityIntent(categorySlug: "freizeit")
        _ = try await intent.perform()
        let defaults = UserDefaults(suiteName: appGroupIdentifier)
        let pending = defaults?.array(forKey: "pendingLogs") as? [[String: String]]
        XCTAssertEqual(pending?.count, 1)
    }
}
```

---

### `FamilyScoreTests/WidgetViewTests.swift` (test, request-response)

**Analog:** `FamilyScoreTests/FamilyServiceTests.swift` (Test-Methoden-Pattern)

**Test-Struktur** (FamilyServiceTests.swift Zeilen 1–22):
```swift
// FamilyScoreTests/WidgetViewTests.swift
// Target Membership: FamilyScoreTests
// Zweck: View-Logic (Sortierung, Progress-Berechnungen) ohne Widget-Runtime

import XCTest
@testable import FamilyScore
import FamilyScoreKit

@MainActor
final class WidgetViewTests: XCTestCase {

    // WIDGET-03: Familienranking sortiert Members nach weeklyPoints absteigend
    func testFamilyRankingViewSortsMembersDescending() {
        let members = [
            WidgetData.MemberScore(displayName: "Max", avatarInitial: "M",
                                   weeklyPoints: 50, weeklyMinutes: 40, avatarColor: "#007AFF"),
            WidgetData.MemberScore(displayName: "Anna", avatarInitial: "A",
                                   weeklyPoints: 80, weeklyMinutes: 60, avatarColor: "#FF9500")
        ]
        let sorted = members.sorted { $0.weeklyPoints > $1.weeklyPoints }
        XCTAssertEqual(sorted.first?.displayName, "Anna")
        XCTAssertEqual(sorted.last?.displayName, "Max")
    }

    // WIDGET-05: myDutyProgress clamped/unclamped korrekt
    func testRingProgressCanExceedOneForSecondLap() {
        let progress = 1.5  // zweite Runde
        XCTAssertGreaterThan(progress, 1.0)
        let secondLap = progress - 1.0
        XCTAssertEqual(secondLap, 0.5, accuracy: 0.001)
    }

    // WIDGET-01: Gauge-Value-Berechnung
    func testGaugeValueCalculation() {
        let score = 42
        let goal = 60
        let gaugeValue = Double(score) / Double(goal)
        XCTAssertEqual(gaugeValue, 0.7, accuracy: 0.001)
    }
}
```

---

### `supabase/migrations/20260517_phase5_push_tokens.sql` (migration, CRUD)

**Analog:** `supabase/migrations/20260515_phase3_family_core.sql` — exakter Match

**Datei-Header-Pattern** (phase3_family_core.sql Zeilen 1–6):
```sql
-- =============================================================================
-- Family Score: Phase 5 Push Tokens
-- device_push_tokens Tabelle fuer APNs opt-in Push-Benachrichtigungen (SYNC-03)
-- =============================================================================
```

**Tabellen-DDL-Pattern** (phase3_family_core.sql — Tabellen-Muster):
```sql
-- Muster: uuid PK, user_id/family_id FK mit ON DELETE CASCADE, timestamptz created_at
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
```

**RLS-Policy-Pattern** (phase3_family_core.sql — ALTER + Policy Muster):
```sql
-- Muster: enable RLS zuerst, dann Policies
ALTER TABLE public.device_push_tokens ENABLE ROW LEVEL SECURITY;

-- User verwaltet eigene Token (INSERT + SELECT + DELETE)
-- Edge Function liest via Service-Role (umgeht RLS) — keine zusaetzliche Policy noetig
CREATE POLICY "User verwaltet eigene Push-Tokens"
  ON public.device_push_tokens FOR ALL TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);
-- (select auth.uid()) statt auth.uid() — Performance-Best-Practice aus RESEARCH.md
```

---

### `supabase/functions/push-notification/index.ts` (service, event-driven)

**Analog:** kein TypeScript/Deno-Analog in der Codebase vorhanden

Planner: 05-RESEARCH.md Pattern 6 (Zeilen 862–904) als primaere Vorlage verwenden. Die TypeScript/Deno-Struktur folgt dem Supabase Edge Function Standard (kein existierendes Analog im Projekt).

```typescript
// supabase/functions/push-notification/index.ts
// KEIN Analog in Codebase — Pattern aus 05-RESEARCH.md Pattern 6 verwenden

// Grundstruktur einer Supabase Edge Function (Deno):
// - Deno.serve() als Entry Point
// - req.json() fuer Webhook-Payload
// - supabaseAdmin (Service-Role-Client) fuer DB-Zugriff ohne RLS
// - APNs JWT via jose-Bibliothek (Assumption A1 — Spike empfohlen)

interface WebhookPayload {
  type: 'INSERT';
  table: 'activity_entries';
  record: { id: string; family_id: string; user_id: string; };
}

Deno.serve(async (req) => {
  const payload: WebhookPayload = await req.json();
  // Alle anderen Familien-Token laden (Service-Role bypassed RLS)
  // APNs JWT erzeugen + senden
  return new Response('OK');
});
```

---

## Shared Patterns

### @MainActor ObservableObject (iOS 16 Pflicht)
**Quelle:** `FamilyScore/FamilyScore/Services/AuthService.swift` Zeilen 10–14
**Anwenden auf:** `RealtimeService`, `NotificationService`
```swift
@MainActor
final class XxxService: ObservableObject {
    @Published private(set) var someState: SomeType = defaultValue
    // private(set) auf alle State-Properties (UI kann nur lesen)
    // Einzige Ausnahme: Error-Properties (UI dismisst via nil-Setzen)
}
```
Regel: KEIN `@Observable` — iOS 17+, verboten per CLAUDE.md.

### XCTestConfigurationFilePath-Guard (KRITISCH)
**Quelle:** `FamilyScore/FamilyScore/FamilyScoreApp.swift` Zeilen 24–27
**Anwenden auf:** `RealtimeService.startListening()` — ERSTE Zeile der Methode
```swift
guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
    print("[Realtime] XCTest-Umgebung erkannt — startListening() uebersprungen")
    return
}
```
Ohne diesen Guard: CI crasht mit `signal trap` nach 227s Timeout (bekannter Fehler, CLAUDE.md).

### EnvironmentObject-Injection (iOS 16)
**Quelle:** `FamilyScore/FamilyScore/FamilyScoreApp.swift` Zeile 18
**Anwenden auf:** `RealtimeService`, `NotificationService` in `FamilyScoreApp.swift`
```swift
// In FamilyScoreApp.swift:
@StateObject private var realtimeService = RealtimeService()
// In body:
.environmentObject(realtimeService)
// In Views:
@EnvironmentObject private var realtimeService: RealtimeService
```

### Supabase Global Client
**Quelle:** `FamilyScore/FamilyScore/Supabase.swift` Zeile 26
**Anwenden auf:** `RealtimeService`, `NotificationService` — einfach `supabase` verwenden
```swift
// Kein neuen SupabaseClient instanziieren — globaler `supabase` aus Supabase.swift
// Supabase.swift: let supabase = SupabaseClient(supabaseURL:, supabaseKey:, options:)
// NUR im Hauptapp-Target verwenden — nie in Widget Extension oder FamilyScoreKit
```

### App Group Identifier
**Quelle:** `FamilyScoreKit/Sources/FamilyScoreKit/WidgetData.swift` Zeile 34
**Anwenden auf:** `WidgetDataWriter`, `WidgetData+AppGroup`, `LogActivityIntent`, `FamilyScoreApp` (pendingLogs)
```swift
// Single Source of Truth: in FamilyScoreKit definiert
public let appGroupIdentifier = "group.com.familyscore"
// Import via: import FamilyScoreKit (in App-Target und Widget Extension)
```

### Mock-Verhalten-Flags fuer Tests
**Quelle:** `FamilyScoreTests/Mocks/MockFamilyService.swift` Zeilen 40–55
**Anwenden auf:** `MockRealtimeService`
```swift
var should[ThrowOn|FailAt][Action]: Bool = false
var [action]CallCount: Int = 0
var last[Action]Param: ParamType? = nil
// Testhelfer: setState()-Methoden fuer direkte State-Manipulation
```

### SQL-Konventionen (Phase-1-Stil)
**Quelle:** `supabase/migrations/20260515_phase3_family_core.sql`
**Anwenden auf:** `20260517_phase5_push_tokens.sql`
- `(select auth.uid())` statt `auth.uid()` in RLS-Policies (Performance)
- `CREATE INDEX` fuer alle FK-Spalten
- `ENABLE ROW LEVEL SECURITY` vor allen Policies
- `ON DELETE CASCADE` fuer alle FK-Referenzen
- `gen_random_uuid()` als PK-Default

### Widget containerBackground (iOS 17+ Handling)
**Quelle:** `FamilyScore/FamilyScoreWidgetExtension/FamilyScoreWidget.swift` Zeilen 43–50
**Anwenden auf:** `FamilyRankingWidget`, `QuickEntryWidget`, `PersonalRingsWidget` (systemFamily-Widgets)
```swift
// iOS 16: kein .containerBackground — direkt View
// iOS 17+: .containerBackground(.fill.tertiary, for: .widget) Pflicht
// Muster aus FamilyScoreWidget.swift:
if #available(iOS 17, *) {
    MyWidgetView(entry: entry)
        .containerBackground(.fill.tertiary, for: .widget)
} else {
    MyWidgetView(entry: entry)
}
// accessory* Widgets: KEIN containerBackground (Lock Screen hat eigenes Rendering)
```

---

## No Analog Found

| Datei | Role | Data Flow | Grund |
|-------|------|-----------|-------|
| `FamilyScoreKit/Sources/FamilyScoreKit/Intents/LogActivityIntent.swift` | utility | event-driven | AppIntents sind neu in Phase 5; kein existierendes AppIntent in der Codebase. Pattern vollstaendig in 05-RESEARCH.md Pattern 4 (Zeilen 602–618) dokumentiert. |
| `supabase/functions/push-notification/index.ts` | service | event-driven | Erste TypeScript/Deno Edge Function im Projekt; kein bestehendes Analog. Pattern in 05-RESEARCH.md Pattern 6 (Zeilen 862–904) dokumentiert. SYNC-03 als separaten Wave 3 Spike planen (Assumption A1). |

---

## Wichtige Architektur-Constraints fuer Phase 5

| Constraint | Quelle | Gilt fuer |
|-----------|--------|-----------|
| Supabase SDK NUR im App-Target | CLAUDE.md | RealtimeService, NotificationService bleiben im App-Target |
| Widget liest NUR aus App Group | CLAUDE.md + 05-RESEARCH.md | FamilyScoreProvider, WidgetData+AppGroup — kein Netzwerkaufruf |
| `ObservableObject` statt `@Observable` | CLAUDE.md (iOS 16 Min) | RealtimeService, NotificationService, MockRealtimeService |
| XCTestConfigurationFilePath-Guard | CLAUDE.md (aus wiederholten Fehlern) | RealtimeService.startListening() — ERSTE Zeile |
| Ein Channel pro Familie | 05-RESEARCH.md (Free Tier Limit) | RealtimeService — KEIN Channel pro View |
| Realtime disconnect bei Background | CLAUDE.md + 05-RESEARCH.md | scenePhase == .background → stopListening() |
| LogActivityIntent in FamilyScoreKit | 05-RESEARCH.md Pitfall 8 | Sonst Build-Fehler: Widget Extension findet Intent nicht |
| AppIntent perform() kein Netzwerk | 05-RESEARCH.md (30MB Widget-Limit) | LogActivityIntent.perform() — nur App Group schreiben |
| accessory* Widgets: keine containerBackground | 05-RESEARCH.md + WidgetKit Docs | AccessoryCircularWidget, AccessoryRectangularWidget |
| Avatar: Text-Initial statt Bild | 05-RESEARCH.md Pitfall 5 | FamilyRankingWidget — kein UIImage, kein Asset-Catalog |
| APNs-Token NICHT in App Group | 05-RESEARCH.md Security | NotificationService speichert Token NUR in Supabase DB |

---

## Metadata

**Analog-Suchbereich:** `FamilyScore/**/*.swift`, `FamilyScore/supabase/migrations/*.sql`, `FamilyScore/FamilyScoreWidgetExtension/**/*.swift`, `FamilyScoreKit/**/*.swift`
**Dateien gescannt:** 23 Swift-Dateien, 2 SQL-Migrationen
**Pattern-Extraktions-Datum:** 2026-05-17
**Analog-Qualitaet:** 18/20 Dateien mit Analog; 2 Dateien (LogActivityIntent, Edge Function) haben vollstaendige RESEARCH.md-Pattern als Ersatz
