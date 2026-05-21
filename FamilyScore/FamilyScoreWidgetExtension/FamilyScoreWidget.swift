import WidgetKit
import SwiftUI
import FamilyScoreKit

struct FamilyScoreProvider: TimelineProvider {
    func placeholder(in context: Context) -> FamilyScoreEntry {
        FamilyScoreEntry(date: Date())
    }

    func getSnapshot(in context: Context,
                     completion: @escaping (FamilyScoreEntry) -> Void) {
        completion(FamilyScoreEntry(date: Date()))
    }

    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<FamilyScoreEntry>) -> Void) {
        #if DEBUG
        let debugDefaults = UserDefaults(suiteName: appGroupIdentifier)
        let appWroteValue = debugDefaults?.bool(forKey: "phase1_verification") ?? false
        print("[Widget] App Group read from Widget: \(appWroteValue ? "PASS" : "FAIL")")
        #endif
        let entry = FamilyScoreEntry(date: Date())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct FamilyScoreEntry: TimelineEntry {
    let date: Date
}

struct FamilyScoreWidgetEntryView: View {
    var entry: FamilyScoreEntry
    var body: some View {
        Text("Family Score")
    }
}

private extension View {
    /// `containerBackground(_:for:)` ist erst ab iOS 17 verfügbar.
    /// Auf iOS 16 (Lock-Screen-Widgets, siehe CLAUDE.md) entfällt der Modifier.
    @ViewBuilder
    func widgetContainerBackground() -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(.fill.tertiary, for: .widget)
        } else {
            self
        }
    }
}

struct FamilyScoreWidget: Widget {
    let kind: String = "FamilyScoreWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FamilyScoreProvider()) { entry in
            FamilyScoreWidgetEntryView(entry: entry)
                .widgetContainerBackground()
        }
        .configurationDisplayName("Family Score")
        .description("Zeigt den Familien-Score.")
    }
}
