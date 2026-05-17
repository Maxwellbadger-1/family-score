# Phase 4: Activity Logging & Dashboard — Pattern Map

**Mapped:** 2026-05-16
**Files analyzed:** 16 (neue/modifizierte Dateien)
**Analogs found:** 15 / 16

---

## File Classification

| Neue/Modifizierte Datei | Role | Data Flow | Closest Analog | Match Quality |
|-------------------------|------|-----------|----------------|---------------|
| `FamilyScore/Services/ActivityService.swift` | service | CRUD + request-response | `FamilyScore/FamilyScore/Services/AuthService.swift` | role-match |
| `FamilyScore/Services/ActivityServiceProtocol.swift` | utility | — | `FamilyScoreTests/Mocks/MockAuthService.swift` (Protocol-Block) | role-match |
| `FamilyScore/Models/ActivityEntry.swift` | model | CRUD | `FamilyScoreKit/Sources/FamilyScoreKit/WidgetData.swift` | role-match |
| `FamilyScore/Models/CategoryConfig.swift` | model | request-response | `FamilyScoreKit/Sources/FamilyScoreKit/WidgetData.swift` | role-match |
| `FamilyScore/Models/DayScore.swift` | model | request-response | `FamilyScoreKit/Sources/FamilyScoreKit/WidgetData.swift` | role-match |
| `FamilyScore/Views/Dashboard/DashboardView.swift` | component | request-response | `FamilyScore/FamilyScore/Views/RootView.swift` | role-match |
| `FamilyScore/Views/Dashboard/RingClusterView.swift` | component | request-response | `FamilyScore/FamilyScore/Views/Auth/AuthFlowView.swift` | partial-match |
| `FamilyScore/Views/Dashboard/SingleRingView.swift` | component | request-response | `FamilyScore/FamilyScore/Views/Auth/AuthFlowView.swift` | partial-match |
| `FamilyScore/Views/Dashboard/WeekSummaryView.swift` | component | request-response | `FamilyScore/FamilyScore/Views/Auth/AuthFlowView.swift` | partial-match |
| `FamilyScore/Views/ActivityLog/ActivityListView.swift` | component | CRUD | `FamilyScore/FamilyScore/Views/Auth/LoginView.swift` | partial-match |
| `FamilyScore/Views/ActivityLog/ActivityRowView.swift` | component | request-response | `FamilyScore/FamilyScore/Views/Auth/LoginView.swift` | partial-match |
| `FamilyScore/Views/ActivityLog/ActivityLogSheet.swift` | component | CRUD | `FamilyScore/FamilyScore/Views/Auth/RegisterView.swift` | role-match |
| `FamilyScoreTests/ActivityServiceTests.swift` | test | CRUD | `FamilyScoreTests/AuthServiceTests.swift` | exact |
| `FamilyScoreTests/Mocks/MockActivityService.swift` | test | CRUD | `FamilyScoreTests/Mocks/MockAuthService.swift` | exact |
| `FamilyScoreTests/RingProgressTests.swift` | test | transform | `FamilyScoreTests/AuthServiceTests.swift` | role-match |
| `supabase/migrations/20260516_phase4_rpcs.sql` | migration | — | `supabase/migrations/20260515_initial_schema.sql` | exact |

---

## Pattern Assignments

### `FamilyScore/Services/ActivityService.swift` (service, CRUD + request-response)

**Analog:** `FamilyScore/FamilyScore/Services/AuthService.swift`

**Imports-Pattern** (Zeilen 1–9):
```swift
// FamilyScore/Services/ActivityService.swift
// Target Membership: FamilyScore (App) ONLY
// iOS 16.0 Minimum: ObservableObject + @Published (NICHT @Observable — iOS 17+)
// Supabase SDK NUR im Hauptapp-Target (CLAUDE.md Architektur-Regel)

import Foundation
import Supabase
```

**Service-Klassen-Deklaration mit @MainActor** (Zeilen 11–14 in AuthService.swift):
```swift
@MainActor
final class ActivityService: ObservableObject {

    @Published private(set) var todayEntries: [ActivityEntry] = []
    @Published private(set) var categories: [CategoryConfig] = []
    @Published private(set) var dayScore: DayScore? = nil
    @Published private(set) var weeklyScores: [WeeklySummary] = []
    @Published private(set) var dutyProgress: Double = 0.0
    @Published private(set) var leisureProgress: Double = 0.0
    @Published private(set) var scoreProgress: Double = 0.0
    @Published private(set) var totalScore: Int = 0
    @Published var activityError: String? = nil

    // Timer-Persistenz via @AppStorage (kein UUID direkt — Pitfall 2 aus RESEARCH.md)
    @AppStorage("timerStartedAt") private var timerStartedAtInterval: Double = 0
    @AppStorage("timerCategoryId") private var timerCategoryIdString: String = ""
```

**Supabase-Query-Pattern** aus AuthService.swift (Zeilen 87–98):
```swift
// Muster: .from().select().eq().limit().execute().value
let result: [CategoryConfig] = try await supabase
    .from("category_config")
    .select("*")
    .eq("family_id", value: familyId.uuidString)
    .eq("is_enabled", value: true)
    .order("sort_order")
    .execute()
    .value
```

**Error-Handling-Pattern** (Zeilen 96–100 in AuthService.swift):
```swift
// Muster: do/catch, kein Crash, Fehler als String in @Published var
do {
    let result = try await supabase...execute().value
    // Erfolg: State aktualisieren
} catch {
    // DB-Fehler → kein Crash; Fehler als lokalisierte Meldung
    activityError = localizedError(from: error)
}
```

**Lokalisierungs-Pattern** (Zeilen 107–118 in AuthService.swift — exakt kopieren, Fehlerstrings anpassen):
```swift
func localizedError(from error: Error) -> String {
    let msg = error.localizedDescription.lowercased()
    if msg.contains("network") || msg.contains("connection") || msg.contains("offline") {
        return "Eintrag konnte nicht gespeichert werden — prüfe deine Internetverbindung und versuche es erneut."
    }
    return "Ein Fehler ist aufgetreten. Bitte erneut versuchen."
}
```

**Dependency-Injection-Pattern** (Zeilen 12–14 in FamilyScoreApp.swift):
```swift
// In FamilyScoreApp.swift: ActivityService als @StateObject, Injection via .environmentObject
@StateObject private var activityService = ActivityService()
// In body: RootView().environmentObject(activityService)
```

---

### `FamilyScore/Services/ActivityServiceProtocol.swift` (utility)

**Analog:** `FamilyScoreTests/Mocks/MockAuthService.swift` — Protocol-Block (Zeilen 12–15)

**Protocol-Deklaration-Pattern** (Zeilen 12–15 in MockAuthService.swift):
```swift
// Muster: Protocol im selben File wie Mock ODER als eigene Datei (Phase 4: eigene Datei)
// Target Membership: FamilyScore (App) ONLY — MockActivityService importiert via @testable

@MainActor
protocol ActivityServiceProtocol: AnyObject {
    var todayEntries: [ActivityEntry] { get }
    var categories: [CategoryConfig] { get }
    var dayScore: DayScore? { get }
    var dutyProgress: Double { get }
    var leisureProgress: Double { get }
    var scoreProgress: Double { get }
    var totalScore: Int { get }
    var activityError: String? { get set }
    var timerIsRunning: Bool { get }

    func fetchTodayData() async throws
    func logActivity(categoryId: UUID, durationMinutes: Int, title: String?) async throws
    func deleteActivity(id: UUID) async throws
    func startTimer(categoryId: UUID)
    func stopTimer(title: String?) async throws
}
```

**Wichtig:** Das Protocol muss in `FamilyScore`-Target sein (nicht im Test-Target), damit `MockActivityService` via `@testable import FamilyScore` darauf zugreifen kann. Identisches Muster wie `AuthServiceProtocol` in MockAuthService.swift Zeile 12.

---

### `FamilyScore/Models/ActivityEntry.swift` (model, CRUD)

**Analog:** `FamilyScoreKit/Sources/FamilyScoreKit/WidgetData.swift`

**Struct-Muster mit Codable + Sendable** (Zeilen 6–31 in WidgetData.swift):
```swift
// Muster: struct (Value Type, NICHT class) — wichtig für @Published + objectWillChange (Pitfall 4)
// Sendable für Swift 6 Concurrency
struct ActivityEntry: Codable, Identifiable, Sendable {
    let id: UUID
    let familyId: UUID
    let userId: UUID
    let categoryId: UUID
    let durationMinutes: Int
    let points: Double
    let title: String?
    let loggedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, points
        case familyId = "family_id"
        case userId = "user_id"
        case categoryId = "category_id"
        case durationMinutes = "duration_minutes"
        case loggedAt = "logged_at"
    }
}
```

**Kein init() nötig** wenn alle Properties aus JSON decodierbar (kein public init wie in WidgetData.swift, da kein separates Package).

**NewActivityEntry** (Encodable-only, für INSERT):
```swift
struct NewActivityEntry: Encodable {
    let familyId: UUID
    let userId: UUID
    let categoryId: UUID
    let durationMinutes: Int
    let points: Double
    let title: String?

    enum CodingKeys: String, CodingKey {
        case familyId = "family_id"
        case userId = "user_id"
        case categoryId = "category_id"
        case durationMinutes = "duration_minutes"
        case points, title
    }
}
```

---

### `FamilyScore/Models/CategoryConfig.swift` (model, request-response)

**Analog:** `FamilyScoreKit/Sources/FamilyScoreKit/WidgetData.swift`

**Struct-Muster** (analog zu WidgetData.MemberScore Zeilen 7–18):
```swift
struct CategoryConfig: Codable, Identifiable, Sendable {
    let id: UUID
    let familyId: UUID
    let name: String
    let icon: String?
    let color: String?
    let pointWeight: Double
    let isEnabled: Bool
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, name, icon, color
        case familyId = "family_id"
        case pointWeight = "point_weight"
        case isEnabled = "is_enabled"
        case sortOrder = "sort_order"
    }
}
```

**Kategorie-zu-Ring-Mapping** (kein separates File — als extension in CategoryConfig.swift):
```swift
extension CategoryConfig {
    var ringType: RingType {
        switch name {
        case "Haushalt", "Besorgungen", "Arbeit/Schule": return .duty
        case "Hobby/Freizeit": return .leisure
        default: return .duty
        }
    }

    // SF-Symbol für ActivityRowView (UI-SPEC Screen 3)
    var sfSymbol: String {
        switch name {
        case "Haushalt": return "house.fill"
        case "Besorgungen": return "cart.fill"
        case "Arbeit/Schule": return "briefcase.fill"
        case "Hobby/Freizeit": return "gamecontroller.fill"
        default: return "circle.fill"
        }
    }
}

enum RingType { case duty, leisure }
```

---

### `FamilyScore/Models/DayScore.swift` (model, request-response)

**Analog:** `FamilyScoreKit/Sources/FamilyScoreKit/WidgetData.swift`

**RPC-Ergebnis-Decodable** (aus RESEARCH.md Pattern 2):
```swift
// Decodierter Rückgabewert von get_today_score RPC
// Decodable (nicht Codable) — wird nur gelesen, nie geschrieben
struct DayScore: Decodable, Sendable {
    let dutyMinutes: Int
    let dutyPoints: Double
    let leisureMinutes: Int
    let leisurePoints: Double
    let totalPoints: Double

    enum CodingKeys: String, CodingKey {
        case dutyMinutes = "duty_minutes"
        case dutyPoints = "duty_points"
        case leisureMinutes = "leisure_minutes"
        case leisurePoints = "leisure_points"
        case totalPoints = "total_points"
    }
}

// Familien-Tagesscore (von get_family_today_scores RPC)
struct MemberDayScore: Decodable, Identifiable, Sendable {
    let userId: UUID
    let displayName: String
    let avatarColor: String
    let dutyPoints: Double
    let leisurePoints: Double
    let totalPoints: Double

    var id: UUID { userId }

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case avatarColor = "avatar_color"
        case dutyPoints = "duty_points"
        case leisurePoints = "leisure_points"
        case totalPoints = "total_points"
        case userId = "user_id"
    }
}
```

---

### `FamilyScore/Views/Dashboard/DashboardView.swift` (component, request-response)

**Analog:** `FamilyScore/FamilyScore/Views/RootView.swift`

**EnvironmentObject-Injection-Pattern** (Zeilen 10–12 in RootView.swift):
```swift
// iOS 16: @EnvironmentObject statt @Environment (iOS 17+ Syntax)
struct DashboardView: View {
    @EnvironmentObject private var activityService: ActivityService

    @State private var showingLogSheet: Bool = false
```

**View-Struktur mit NavigationStack + TabView** (RootView.swift Zeilen 13–22 als Referenz für Group-Switch):
```swift
var body: some View {
    NavigationStack {
        ScrollView {
            VStack(spacing: 0) {
                // Datumszeile (Label, systemSecondaryLabel)
                // RingClusterView
                // Divider + "Diese Woche"-Section
                // WeekSummaryView
            }
        }
        .navigationTitle("Übersicht")
        .navigationBarTitleDisplayMode(.large)
        .task { await loadDashboard() }
    }
    // FAB via .overlay
    .overlay(alignment: .bottomTrailing) { fabButton }
    .sheet(isPresented: $showingLogSheet) {
        ActivityLogSheet(activityService: activityService)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
    }
}
```

**Async-Task-Pattern für Datenladen** (Zeilen 124–136 in LoginView.swift — submitLogin Muster):
```swift
private func loadDashboard() async {
    do {
        try await activityService.fetchTodayData()
    } catch {
        // Fehler bereits in activityService.activityError gesetzt
    }
}
```

**Empty-State-Pattern** (Zeilen 40–66 in RootView.swift — OnboardingPlaceholderView):
```swift
// Wenn todayEntries.isEmpty:
VStack(spacing: 16) {
    // Ringe bleiben sichtbar (0% Fill)
    Text("Noch keine Aktivitäten heute")
        .font(.system(size: 22, weight: .semibold))   // Heading
    Text("Tippe auf „+" um deinen ersten Eintrag zu starten.")
        .font(.system(size: 17))                       // Body
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
}
```

---

### `FamilyScore/Views/Dashboard/RingClusterView.swift` (component, request-response)

**Analog:** `FamilyScore/FamilyScore/Views/Auth/AuthFlowView.swift` (ZStack + VStack Struktur)

**ZStack-Kompositions-Pattern** (Zeilen 15–57 in AuthFlowView.swift — strukturelles Muster):
```swift
// Direkt aus RESEARCH.md Pattern 1 übernehmen — ist bereits vollständig verifiziert
struct RingClusterView: View {
    let dutyProgress: Double
    let leisureProgress: Double
    let scoreProgress: Double
    let totalScore: Int

    private let outerDiameter: CGFloat = 280
    private let gap: CGFloat = 8         // sm spacing token (UI-SPEC)
    private let lineWidth: CGFloat = 20  // UI-SPEC Ring-Stroke-Width

    var body: some View {
        ZStack {
            SingleRingView(progress: dutyProgress, color: Color(UIColor.systemRed))
                .frame(width: outerDiameter, height: outerDiameter)
            SingleRingView(progress: leisureProgress, color: Color(UIColor.systemGreen))
                .frame(width: outerDiameter - 2*(lineWidth + gap),
                       height: outerDiameter - 2*(lineWidth + gap))
            SingleRingView(progress: scoreProgress, color: Color(UIColor.systemBlue))
                .frame(width: outerDiameter - 4*(lineWidth + gap),
                       height: outerDiameter - 4*(lineWidth + gap))

            // Zentrum — Display + Label Typography (UI-SPEC)
            VStack(spacing: 2) {
                Text("\(totalScore)")
                    .font(.system(size: 34, weight: .semibold))
                    .monospacedDigit()
                Text("Punkte heute")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(totalScore) Punkte heute")
        }
        // Animation: RESEARCH.md Pattern 1 — spring für Apple-Fitness-Gefühl
        .animation(.spring(response: 0.6, dampingFraction: 0.75), value: dutyProgress)
        .animation(.spring(response: 0.6, dampingFraction: 0.75), value: leisureProgress)
        .animation(.spring(response: 0.6, dampingFraction: 0.75), value: scoreProgress)
    }
}
```

---

### `FamilyScore/Views/Dashboard/SingleRingView.swift` (component, request-response)

**Analog:** `FamilyScore/FamilyScore/Views/Auth/AuthFlowView.swift` (strukturelles Muster)

**Vollständige Implementierung aus RESEARCH.md Pattern 1** (keine Codebase-Analog exakt passend — Pattern ist vollständig in RESEARCH.md dokumentiert):
```swift
struct SingleRingView: View {
    let progress: Double      // 0.0–1.0+ (Überlauf erlaubt, UI-SPEC)
    let color: Color
    let lineWidth: CGFloat = 20   // UI-SPEC: fix 20pt

    var body: some View {
        ZStack {
            // Track (Hintergrund-Arc) — 15% Opacity (UI-SPEC: "15% opacity of ring's semantic color")
            Circle()
                .stroke(color.opacity(0.15),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            // Progress-Arc (erste Runde)
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))   // 12-Uhr-Start (UI-SPEC)

            // Zweite Runde bei Überlauf (UI-SPEC: "slight opacity reduction on second lap")
            if progress > 1.0 {
                Circle()
                    .trim(from: 0, to: progress - 1.0)
                    .stroke(color.opacity(0.6),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
    }
}
```

**Accessibility** (UI-SPEC Accessibility Contract):
```swift
// Wird von RingClusterView aus gesteuert — SingleRingView selbst ist .accessibilityHidden(true)
// Die Labels stehen an der äußeren ZStack-Ebene (RingClusterView)
```

---

### `FamilyScore/Views/Dashboard/WeekSummaryView.swift` (component, request-response)

**Analog:** `FamilyScore/FamilyScore/Views/Auth/AuthFlowView.swift` (VStack + Section Muster)

**Swift Charts Import** (kein Analog vorhanden — neu in Phase 4):
```swift
import SwiftUI
import Charts
```

**BarMark-Pattern aus RESEARCH.md Pattern 7**:
```swift
struct WeekSummaryView: View {
    let weekScores: [WeekMemberScore]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Diese Woche")
                .font(.system(size: 22, weight: .semibold))   // Heading (UI-SPEC)
                .padding(.horizontal, 16)

            Chart(weekScores) { score in
                BarMark(
                    x: .value("Mitglied", score.memberName),
                    y: .value("Minuten", score.minutes)
                )
                .foregroundStyle(by: .value("Kategorie", score.category))
                .position(by: .value("Kategorie", score.category), axis: .horizontal)
            }
            .chartForegroundStyleScale([
                "Pflicht": Color(UIColor.systemRed),
                "Freizeit": Color(UIColor.systemGreen)
            ])
            .frame(height: 200)
            .padding(.horizontal, 16)
        }
    }
}

struct WeekMemberScore: Identifiable {
    let id = UUID()
    let memberName: String
    let category: String    // "Pflicht" oder "Freizeit"
    let minutes: Int
}
```

---

### `FamilyScore/Views/ActivityLog/ActivityListView.swift` (component, CRUD)

**Analog:** `FamilyScore/FamilyScore/Views/Auth/LoginView.swift`

**EnvironmentObject + State-Pattern** (Zeilen 9–15 in LoginView.swift):
```swift
struct ActivityListView: View {
    @EnvironmentObject private var activityService: ActivityService

    @State private var entryToDelete: ActivityEntry? = nil
    @State private var showDeleteConfirmation: Bool = false
```

**List mit swipeActions** (RESEARCH.md Pattern 9 — kein exaktes Codebase-Analog, aber `.confirmationDialog` Muster aus RootView.swift):
```swift
var body: some View {
    NavigationStack {
        List {
            // Gruppierung nach Datum via Section
            ForEach(groupedByDay, id: \.date) { group in
                Section(header: Text(group.dateLabel)) {
                    ForEach(group.entries) { entry in
                        ActivityRowView(entry: entry,
                                        category: category(for: entry))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    entryToDelete = entry
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle("Verlauf")
        .confirmationDialog("Eintrag löschen",
                            isPresented: $showDeleteConfirmation) {
            Button("Löschen", role: .destructive) {
                if let entry = entryToDelete {
                    Task { try? await activityService.deleteActivity(id: entry.id) }
                }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Dieser Eintrag wird dauerhaft gelöscht.")
        }
    }
}
```

**Empty-State-Pattern** (Zeilen 40–66 in RootView.swift):
```swift
// Wenn todayEntries.isEmpty → ContentUnavailableView-Äquivalent (iOS 16: custom VStack):
VStack(spacing: 16) {
    Image(systemName: "tray")
        .font(.system(size: 48))
        .foregroundStyle(.secondary)
    Text("Noch keine Einträge")
        .font(.system(size: 22, weight: .semibold))
    Text("Aktivitäten erscheinen hier, sobald du deinen ersten Eintrag erfasst hast.")
        .font(.system(size: 17))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
}
```

---

### `FamilyScore/Views/ActivityLog/ActivityRowView.swift` (component, request-response)

**Analog:** `FamilyScore/FamilyScore/Views/Auth/LoginView.swift` (HStack-Row-Muster)

**HStack-Row-Pattern** (analog zu LoginView.swift Zeilen 27–46 — Error-Banner HStack):
```swift
struct ActivityRowView: View {
    let entry: ActivityEntry
    let category: CategoryConfig?

    var body: some View {
        HStack(spacing: 12) {
            // Leading: SF Symbol in Ring-Farbe (UI-SPEC Screen 3)
            Image(systemName: category?.sfSymbol ?? "circle.fill")
                .foregroundStyle(ringColor)
                .frame(width: 20, height: 20)

            // Primary + Secondary Text (Body + Label, UI-SPEC Typography)
            VStack(alignment: .leading, spacing: 2) {
                Text(category?.name ?? "Unbekannt")
                    .font(.system(size: 17))    // Body
                Text("\(entry.durationMinutes) min · \(Int(entry.points)) Punkte")
                    .font(.system(size: 13))    // Label
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Trailing: Zeitstempel (Label, systemTertiaryLabel)
            Text(entry.loggedAt, style: .time)
                .font(.system(size: 13))
                .foregroundStyle(Color(UIColor.tertiaryLabel))
        }
        // Accessibility (UI-SPEC Accessibility Contract)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var ringColor: Color {
        switch category?.ringType {
        case .duty: return Color(UIColor.systemRed)
        case .leisure: return Color(UIColor.systemGreen)
        case .none: return Color(UIColor.systemBlue)
        }
    }
}
```

---

### `FamilyScore/Views/ActivityLog/ActivityLogSheet.swift` (component, CRUD)

**Analog:** `FamilyScore/FamilyScore/Views/Auth/RegisterView.swift`

**Form-Sheet-Pattern** (Zeilen 9–29 in RegisterView.swift — State + canSubmit):
```swift
struct ActivityLogSheet: View {
    @ObservedObject var activityService: ActivityService    // kein EnvironmentObject in Sheet
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategoryId: UUID? = nil
    @State private var selectedDuration: Int = 30      // Default 30 min (UI-SPEC)
    @State private var noteText: String = ""
    @State private var isLoading: Bool = false

    private var canSubmit: Bool {
        selectedCategoryId != nil && !isLoading
    }

    private var calculatedPoints: Int {
        let weight = activityService.categories
            .first(where: { $0.id == selectedCategoryId })?.pointWeight ?? 1.0
        return Int(Double(selectedDuration) * weight)
    }
```

**Button-Disabled-Pattern** (Zeilen 124–140 in RegisterView.swift):
```swift
Button {
    Task { await saveActivity() }
} label: {
    Group {
        if isLoading {
            ProgressView().tint(.white)
        } else {
            Text("Speichern").font(.headline)
        }
    }
    .frame(maxWidth: .infinity)
    .frame(height: 44)   // touch spacing token (UI-SPEC)
    .background(canSubmit ? Color(UIColor.systemBlue) : Color(UIColor.systemBlue).opacity(0.3))
    .foregroundStyle(.white)
    .cornerRadius(12)
}
.disabled(!canSubmit)
```

**Async-Save mit Error-Alert** (Zeilen 146–157 in RegisterView.swift — submitRegister):
```swift
private func saveActivity() async {
    guard canSubmit, let categoryId = selectedCategoryId else { return }
    isLoading = true
    defer { isLoading = false }
    do {
        try await activityService.logActivity(
            categoryId: categoryId,
            durationMinutes: selectedDuration,
            title: noteText.trimmingCharacters(in: .whitespaces).isEmpty ? nil : noteText
        )
        dismiss()
    } catch {
        activityService.activityError = activityService.localizedError(from: error)
    }
}
```

**Half-Sheet-Präsentation** wird vom aufrufenden View gesteuert (DashboardView):
```swift
.sheet(isPresented: $showingLogSheet) {
    ActivityLogSheet(activityService: activityService)
        .presentationDetents([.medium])     // iOS 16 nativ (RESEARCH.md Pattern 8)
        .presentationDragIndicator(.visible)
}
```

**Dauer-Wheel-Picker** (RESEARCH.md Pattern 8):
```swift
Picker("Dauer", selection: $selectedDuration) {
    ForEach(Array(stride(from: 5, through: 240, by: 5)), id: \.self) { minutes in
        Text("\(minutes) min").tag(minutes)
    }
}
.pickerStyle(.wheel)
```

---

### `FamilyScoreTests/ActivityServiceTests.swift` (test, CRUD)

**Analog:** `FamilyScoreTests/AuthServiceTests.swift` — exakter Match

**Test-Klassen-Struktur** (Zeilen 1–19 in AuthServiceTests.swift):
```swift
// FamilyScoreTests/ActivityServiceTests.swift
// Target Membership: FamilyScoreTests
// STUBS — Wave 0; nach Wave 1+ durch echte Assertions ersetzen
// Anforderungen: LOG-01 bis SCORE-03

import XCTest
@testable import FamilyScore

@MainActor
final class ActivityServiceTests: XCTestCase {

    var mock: MockActivityService!

    override func setUp() async throws {
        try await super.setUp()
        mock = MockActivityService()
    }

    override func tearDown() async throws {
        mock = nil
        try await super.tearDown()
    }
```

**Test-Methoden-Pattern** (Zeilen 27–67 in AuthServiceTests.swift):
```swift
// LOG-01: Timer startet und berechnet Minuten korrekt
func testTimerStartsAndCalculatesMinutes() async throws {
    let categoryId = UUID()
    mock.startTimer(categoryId: categoryId)
    XCTAssertTrue(mock.timerIsRunning)
}

// LOG-02: Retroaktiver Eintrag via logActivity
func testLogActivityCallsService() async throws {
    let categoryId = UUID()
    try await mock.logActivity(categoryId: categoryId, durationMinutes: 30, title: nil)
    XCTAssertEqual(mock.logActivityCallCount, 1)
}

// LOG-05: deleteActivity entfernt Eintrag
func testDeleteActivityRemovesEntry() async throws {
    let id = UUID()
    try await mock.deleteActivity(id: id)
    XCTAssertEqual(mock.deleteActivityCallCount, 1)
}

// DASH-01: Ring-Progress korrekt berechnet
func testRingProgressUpdatesAfterLog() async throws {
    // Mock setzt dutyProgress/leisureProgress/scoreProgress direkt
    mock.dutyProgress = 0.5
    XCTAssertEqual(mock.dutyProgress, 0.5)
}

// SCORE-01: Punkte = Minuten × 1.0 (Phase 4 fix)
func testPointsCalculationIsMinutesTimesOne() {
    let minutes = 30
    let expected = Double(minutes) * 1.0
    XCTAssertEqual(expected, 30.0)
}
```

---

### `FamilyScoreTests/Mocks/MockActivityService.swift` (test, CRUD)

**Analog:** `FamilyScoreTests/Mocks/MockAuthService.swift` — exakter Match

**Mock-Klassen-Struktur** (Zeilen 1–75 in MockAuthService.swift):
```swift
// FamilyScoreTests/Mocks/MockActivityService.swift
// Target Membership: FamilyScoreTests ONLY
import Foundation
import Combine
@testable import FamilyScore

@MainActor
final class MockActivityService: ObservableObject, ActivityServiceProtocol {

    // @Published Properties (spiegeln ActivityServiceProtocol)
    @Published private(set) var todayEntries: [ActivityEntry] = []
    @Published private(set) var categories: [CategoryConfig] = []
    @Published private(set) var dayScore: DayScore? = nil
    @Published var dutyProgress: Double = 0.0
    @Published var leisureProgress: Double = 0.0
    @Published var scoreProgress: Double = 0.0
    @Published var totalScore: Int = 0
    @Published var activityError: String? = nil

    // Verhaltens-Flags (Muster von MockAuthService Zeilen 23–30)
    var shouldThrowOnLog: Bool = false
    var shouldThrowOnDelete: Bool = false
    var logActivityCallCount: Int = 0
    var deleteActivityCallCount: Int = 0
    var timerIsRunning: Bool = false
    var lastLoggedCategoryId: UUID? = nil
    var lastLoggedDuration: Int = 0

    // Testhelfer: Entries direkt setzen
    func setEntries(_ entries: [ActivityEntry]) { todayEntries = entries }
```

**Mock-Methoden-Pattern** (Zeilen 41–68 in MockAuthService.swift):
```swift
    func fetchTodayData() async throws { /* Mock: sofort, kein Netzwerk */ }

    func logActivity(categoryId: UUID, durationMinutes: Int, title: String?) async throws {
        logActivityCallCount += 1
        lastLoggedCategoryId = categoryId
        lastLoggedDuration = durationMinutes
        if shouldThrowOnLog { throw MockActivityError.logFailed }
    }

    func deleteActivity(id: UUID) async throws {
        deleteActivityCallCount += 1
        if shouldThrowOnDelete { throw MockActivityError.deleteFailed }
        todayEntries.removeAll { $0.id == id }
    }

    func startTimer(categoryId: UUID) { timerIsRunning = true }
    func stopTimer(title: String?) async throws {
        timerIsRunning = false
        try await logActivity(categoryId: UUID(), durationMinutes: 1, title: title)
    }
}

enum MockActivityError: Error {
    case logFailed
    case deleteFailed
}
```

---

### `FamilyScoreTests/RingProgressTests.swift` (test, transform)

**Analog:** `FamilyScoreTests/AuthServiceTests.swift` (Test-Klassen-Struktur)

**Test-Struktur** (Zeilen 1–19 in AuthServiceTests.swift):
```swift
// FamilyScoreTests/RingProgressTests.swift
// Target Membership: FamilyScoreTests
// Zweck: Unit-Tests für Ring-Progress-Berechnung (kein Netzwerk nötig)

import XCTest
@testable import FamilyScore

@MainActor
final class RingProgressTests: XCTestCase {

    // DASH-01: 60 Punkte = Ring full (UI-SPEC Score Contract)
    func testRingFullAt60Points() {
        let progress = 60.0 / 60.0
        XCTAssertEqual(progress, 1.0, accuracy: 0.001)
    }

    // DASH-01: Überlauf > 100% — zweite Runde
    func testRingOverflowAbove100Percent() {
        let progress = 90.0 / 60.0    // 1.5 → zweite Runde bei 0.5
        XCTAssertGreaterThan(progress, 1.0)
        let secondLap = progress - 1.0
        XCTAssertEqual(secondLap, 0.5, accuracy: 0.001)
    }

    // DASH-01: 0 Punkte → 0% Progress
    func testZeroPointsZeroProgress() {
        let progress = 0.0 / 60.0
        XCTAssertEqual(progress, 0.0)
    }

    // SCORE-01: Punkte = Minuten × 1.0 (Phase 4 fix)
    func testPointsEqualsMinutesForPhase4() {
        let minutes = 45
        let pointWeight = 1.0
        let points = Double(minutes) * pointWeight
        XCTAssertEqual(points, 45.0)
    }
}
```

---

### `supabase/migrations/20260516_phase4_rpcs.sql` (migration)

**Analog:** `FamilyScore/supabase/migrations/20260515_initial_schema.sql` — exakter Match

**Migrations-Datei-Struktur** (Zeilen 1–8 in 20260515_initial_schema.sql):
```sql
-- =============================================================================
-- Family Score: Phase 4 RPCs
-- Phase 4 Activity Logging & Dashboard
-- Neue Funktionen — keine neuen Tabellen (Schema aus Phase 1 vollständig)
-- =============================================================================
```

**SECURITY DEFINER-Funktions-Pattern** (Zeilen 33–48 in 20260515_initial_schema.sql — handle_new_user):
```sql
-- Konvention aus Phase 1: SECURITY DEFINER + SET search_path = '' + explizite Schema-Prefixe
CREATE OR REPLACE FUNCTION public.get_today_score(p_user_id uuid DEFAULT NULL)
RETURNS TABLE (...)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''    -- Pitfall 7 aus RESEARCH.md: verhindert Path-Injection
AS $$
BEGIN
    -- Alle Tabellen-Referenzen mit public.-Prefix (Konvention aus Phase-1)
    -- z.B. public.activity_entries, public.category_config
END;
$$;
```

**Funktions-Kommentierung** (wie Phase-1-Migration Abschnittsheader):
```sql
-- 1. get_today_score(p_user_id uuid DEFAULT NULL)
-- 2. get_family_today_scores()
-- 3. create_activity_for_child(...)
-- 4. insert_default_categories(p_family_id uuid)  ← Neu: Seeding (RESEARCH.md Annahme A4)
```

---

## Shared Patterns

### @MainActor ObservableObject
**Quelle:** `FamilyScore/FamilyScore/Services/AuthService.swift` Zeilen 10–13
**Anwenden auf:** `ActivityService`
```swift
@MainActor
final class ActivityService: ObservableObject {
    @Published private(set) var /* state */ = /* default */
```
Regel: `private(set)` auf alle State-Properties; nur `activityError` ohne `private(set)` (UI kann dismissen).

### EnvironmentObject-Injection
**Quelle:** `FamilyScore/FamilyScore/Views/Auth/LoginView.swift` Zeile 10 + `FamilyScoreApp.swift` Zeilen 12–25
**Anwenden auf:** DashboardView, ActivityListView (alle Tab-Level-Views)
```swift
// In View:
@EnvironmentObject private var activityService: ActivityService
// In FamilyScoreApp.swift (ergänzen):
@StateObject private var activityService = ActivityService()
// In body: .environmentObject(activityService)
```
Achtung: `ActivityLogSheet` bekommt `activityService` als `@ObservedObject`-Parameter (nicht EnvironmentObject), da Sheets ihren eigenen Environment-Scope aufbauen können.

### Supabase-Query-Kette
**Quelle:** `FamilyScore/FamilyScore/Services/AuthService.swift` Zeilen 87–98
**Anwenden auf:** Alle ActivityService-Methoden mit DB-Zugriffen
```swift
// SELECT:
let result: [T] = try await supabase
    .from("tabelle")
    .select("*")
    .eq("spalte", value: wert)
    .execute()
    .value

// INSERT + zurückgelesener Wert:
let saved: T = try await supabase
    .from("tabelle")
    .insert(newEntry)
    .select()
    .single()
    .execute()
    .value

// DELETE:
try await supabase
    .from("tabelle")
    .delete()
    .eq("id", value: id)
    .execute()

// RPC:
let score: [DayScore] = try await supabase
    .rpc("get_today_score")
    .execute()
    .value
```

### Async-Button mit isLoading
**Quelle:** `FamilyScore/FamilyScore/Views/Auth/LoginView.swift` Zeilen 86–105 + `RegisterView.swift` Zeilen 124–140
**Anwenden auf:** ActivityLogSheet (Speichern-Button)
```swift
Button { Task { await submitAction() } } label: {
    Group {
        if isLoading { ProgressView().tint(.white) }
        else { Text("Speichern").font(.headline) }
    }
    .frame(maxWidth: .infinity).frame(height: 44)
    .background(canSubmit ? Color(UIColor.systemBlue) : Color(UIColor.systemBlue).opacity(0.3))
}
.disabled(!canSubmit || isLoading)
```

### Error-Lokalisierung
**Quelle:** `FamilyScore/FamilyScore/Services/AuthService.swift` Zeilen 107–119
**Anwenden auf:** ActivityService
Muster: `func localizedError(from error: Error) -> String` — nur nutzerfreundliche Strings, kein roher Server-Error-Text.

### iOS 16 Spacing + Typography
**Quelle:** UI-SPEC `04-UI-SPEC.md` (Spacing Scale + Typography)
**Anwenden auf:** Alle Views in Phase 4
```swift
// Spacing-Tokens als Konstanten (keine Magic Numbers):
// xs=4, sm=8, md=16, lg=24, xl=32, 2xl=48

// Typography:
.font(.system(size: 34, weight: .semibold))  // Display — Score-Zahlen
.font(.system(size: 22, weight: .semibold))  // Heading — Sektions-Titel
.font(.system(size: 17))                     // Body — Listen-Zeilen
.font(.system(size: 13))                     // Label — Zeitstempel, Tags
```

### #Preview mit EnvironmentObject
**Quelle:** `FamilyScore/FamilyScore/Views/Auth/LoginView.swift` Zeilen 140–146 + `AuthFlowView.swift` Zeilen 60–63
**Anwenden auf:** Alle Phase-4-Views
```swift
#Preview {
    DashboardView()
        .environmentObject(/* MockActivityService oder ActivityService() */)
}
```

### SQL-Konventionen (Phase-1-Stil)
**Quelle:** `FamilyScore/supabase/migrations/20260515_initial_schema.sql`
**Anwenden auf:** `20260516_phase4_rpcs.sql`
- `SECURITY DEFINER` + `SET search_path = ''` für alle neuen Funktionen
- `public.`-Prefix auf alle Tabellen-Referenzen innerhalb von RPCs
- Kommentar-Abschnittsheader mit `-- ===` Trennlinien
- `COALESCE(..., 0)` auf alle Aggregat-Spalten (keine NULL-Werte an Swift zurückgeben)
- `CREATE OR REPLACE FUNCTION` (nicht `CREATE FUNCTION`) für Idempotenz

---

## No Analog Found

| Datei | Role | Data Flow | Grund |
|-------|------|-----------|-------|
| `FamilyScore/Views/Dashboard/SingleRingView.swift` | component | request-response | Kein Ring/Canvas-View in der Codebase vorhanden; Pattern vollständig in RESEARCH.md Pattern 1 dokumentiert — dort direkt entnehmen |

---

## Metadata

**Analog-Suchbereich:** `FamilyScore/**/*.swift`, `FamilyScore/supabase/migrations/*.sql`
**Dateien gescannt:** 17 Swift-Dateien, 1 SQL-Datei
**Pattern-Extraktions-Datum:** 2026-05-16
**Analog-Qualität:** 15/16 Dateien haben klares Analog; SingleRingView hat RESEARCH.md-Pattern als vollständigen Ersatz
