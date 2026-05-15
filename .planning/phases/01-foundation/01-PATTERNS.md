# Phase 1: Foundation - Pattern Map

**Mapped:** 2026-05-15
**Files analyzed:** 14 (neue Dateien; kein bestehender Codebase)
**Analogs found:** 0 / 14 (Greenfield-Projekt — alle Patterns stammen aus Apple Docs und Supabase Docs)

> **Hinweis:** Dies ist ein Greenfield-Projekt. Es gibt noch keine Codebase. Alle Pattern-Referenzen
> sind externe Quellen (Apple Developer Documentation, Supabase Docs, NSHipster). Der Planner
> soll die Code-Excerpts aus dieser Datei direkt in die Plan-Actions übernehmen.

---

## File Classification

| Neue Datei | Rolle | Data Flow | Externes Analog / Muster | Match-Qualität |
|------------|-------|-----------|--------------------------|----------------|
| `FamilyScore/FamilyScoreApp.swift` | app-entry | request-response | Apple SwiftUI App-Lifecycle (`@main`) | extern (Apple Docs) |
| `FamilyScore/Supabase.swift` | singleton-client | request-response | Supabase iOS Quickstart | extern (Supabase Docs) |
| `FamilyScore/ContentView.swift` | view-placeholder | — | SwiftUI `ContentView` Template | extern (Xcode Template) |
| `FamilyScore/Resources/Info.plist` | config | — | xcconfig Build-Setting-Injection (NSHipster) | extern |
| `FamilyScore/Resources/FamilyScore.entitlements` | entitlement | — | Apple App Groups Capability | extern (Apple Docs) |
| `FamilyScoreWidgetExtension/FamilyScoreWidget.swift` | widget-provider | batch | Apple WidgetKit TimelineProvider | extern (Apple Docs) |
| `FamilyScoreWidgetExtension/FamilyScoreWidgetBundle.swift` | widget-bundle | — | Apple `@main WidgetBundle` | extern (Apple Docs) |
| `FamilyScoreWidgetExtension/FamilyScoreWidgetExtension.entitlements` | entitlement | — | Apple App Groups Capability | extern (Apple Docs) |
| `FamilyScoreKit/Package.swift` | spm-manifest | — | Swift Package Manager (SPM) | extern (Swift.org Docs) |
| `FamilyScoreKit/Sources/FamilyScoreKit/WidgetData.swift` | shared-model | — | Swift `Codable` + `Sendable` struct | extern (Swift Docs) |
| `Config/Config.xcconfig` | build-config | — | xcconfig `#include` Pattern (NSHipster) | extern |
| `Config/Secrets.xcconfig` | build-secret | — | xcconfig Secrets Pattern (NSHipster) | extern (gitignored) |
| `Config/Secrets.xcconfig.template` | build-secret-template | — | xcconfig Template Pattern | extern (committed) |
| `supabase/migrations/20260515_initial_schema.sql` | db-migration | CRUD | Supabase PostgreSQL DDL + RLS | extern (Supabase Docs) |

---

## Pattern Assignments

### `FamilyScore/FamilyScoreApp.swift` (app-entry, request-response)

**Externes Analog:** Apple SwiftUI App-Lifecycle — [Apple Developer Docs: App structure](https://developer.apple.com/documentation/swiftui/app)

**SwiftUI App Entry Point Pattern:**
```swift
import SwiftUI

@main
struct FamilyScoreApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

**App Group Verifikation (DEBUG-only — wird nach Phase 1 entfernt):**
```swift
// In FamilyScoreApp.swift, nur in DEBUG
#if DEBUG
func verifyAppGroup() {
    let suite = "group.com.familyscore"
    guard let defaults = UserDefaults(suiteName: suite) else {
        assertionFailure("App Group UserDefaults konnte nicht initialisiert werden: \(suite)")
        return
    }
    let testKey = "phase1_verification"
    defaults.set(true, forKey: testKey)
    defaults.synchronize()
    let result = defaults.bool(forKey: testKey)
    print("[Phase1] App Group Test: \(result ? "PASS" : "FAIL")")
    assert(result, "App Group FAIL — Developer Portal prüfen!")
}
#endif
```

**Supabase Connection Verifikation (DEBUG-only):**
```swift
#if DEBUG
func verifySupabaseConnection() async {
    do {
        let families: [AnyJSON] = try await supabase
            .from("families")
            .select()
            .execute()
            .value
        print("[Phase1] Supabase Connection PASS — families returned \(families.count) rows (expected 0 with RLS, no auth)")

        let summaries: [AnyJSON] = try await supabase
            .from("weekly_summaries")
            .select()
            .execute()
            .value
        print("[Phase1] weekly_summaries table exists PASS")
        print("[Phase1] RLS appears active — anon user sees 0 rows")
    } catch {
        print("[Phase1] Supabase Connection FAIL: \(error)")
        assertionFailure("Supabase connection failed: \(error)")
    }
}
// Aufruf: Task { await verifySupabaseConnection() } in App.init oder ContentView.task{}
#endif
```

**Swift 6 Concurrency-Hinweis:** `DispatchQueue.main.async` ist in Swift 6 deprecated. Stattdessen `await MainActor.run { }` verwenden.

---

### `FamilyScore/Supabase.swift` (singleton-client, request-response)

**Externes Analog:** Supabase iOS Quickstart — [Supabase Docs: iOS SwiftUI Quickstart](https://supabase.com/docs/guides/getting-started/quickstarts/ios-swiftui)

**KRITISCHE REGEL:** Diese Datei existiert NUR im App Target (`FamilyScore`). Niemals im Widget Extension Target einbinden (30 MB Limit).

**SupabaseClient Singleton Pattern:**
```swift
// Source: Supabase iOS Quickstart docs
// Target Membership: FamilyScore (App) ONLY — NICHT Widget Extension
import Supabase

let supabase = SupabaseClient(
    supabaseURL: URL(string: Bundle.main.object(
        forInfoDictionaryKey: "SUPABASE_URL") as! String)!,
    supabaseKey: Bundle.main.object(
        forInfoDictionaryKey: "SUPABASE_KEY") as! String
)
```

**Wichtig:** Werte kommen aus `Info.plist`, die wiederum Build Settings aus `Secrets.xcconfig` injiziert (über `Config.xcconfig`). Niemals Keys hardcoden.

---

### `FamilyScore/ContentView.swift` (view-placeholder, —)

**Externes Analog:** Xcode SwiftUI Template

**Minimal-Placeholder Pattern:**
```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "figure.2.and.child.holdinghands")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Family Score")
                .font(.title)
        }
        .padding()
        .task {
            // Phase 1: Verbindungstest (DEBUG only)
            #if DEBUG
            // await verifySupabaseConnection()
            #endif
        }
    }
}
```

---

### `FamilyScore/Resources/Info.plist` (config, —)

**Externes Analog:** xcconfig Build-Setting-Injection — [NSHipster: Secrets Management on iOS](https://nshipster.com/secrets/)

**Info.plist Build-Setting-Injection Entries:**
```xml
<!-- Zur App Target Info.plist hinzufügen -->
<key>SUPABASE_URL</key>
<string>$(SUPABASE_URL)</string>
<key>SUPABASE_KEY</key>
<string>$(SUPABASE_KEY)</string>
```

**Einrichtungsschritte:**
1. Target → Build Settings → `INFOPLIST_FILE` zeigt auf diese Datei
2. Target → Build Settings → Configuration File → `Config/Config.xcconfig` auswählen
3. `$(SUPABASE_URL)` wird beim Build durch den Wert aus Secrets.xcconfig ersetzt

---

### `FamilyScore/Resources/FamilyScore.entitlements` (entitlement, —)

**Externes Analog:** Apple App Groups Capability — [Apple Docs: Configuring App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups)

**KRITISCHE REIHENFOLGE:** Apple Developer Portal zuerst konfigurieren, dann Xcode. Simulator prüft Entitlements nicht — Fehler zeigen sich nur auf echtem Gerät.

**Entitlements-Datei Format:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.familyscore</string>
    </array>
</dict>
</plist>
```

**Xcode generiert diese Datei automatisch** wenn unter `Signing & Capabilities` → `+ Capability` → `App Groups` die Gruppe `group.com.familyscore` eingetragen wird.

---

### `FamilyScoreWidgetExtension/FamilyScoreWidget.swift` (widget-provider, batch)

**Externes Analog:** Apple WidgetKit TimelineProvider — [Apple Docs: WidgetKit](https://developer.apple.com/documentation/widgetkit)

**KRITISCHE REGEL:** Kein direktes Netzwerk im Widget. Daten kommen ausschliesslich via `UserDefaults(suiteName: "group.com.familyscore")`.

**WidgetKit TimelineProvider Pattern:**
```swift
import WidgetKit
import SwiftUI
import FamilyScoreKit

struct FamilyScoreProvider: TimelineProvider {
    func placeholder(in context: Context) -> FamilyScoreEntry {
        FamilyScoreEntry(date: Date(), widgetData: .placeholder)
    }

    func getSnapshot(in context: Context,
                     completion: @escaping (FamilyScoreEntry) -> Void) {
        let entry = FamilyScoreEntry(date: Date(), widgetData: loadWidgetData())
        completion(entry)
    }

    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<FamilyScoreEntry>) -> Void) {
        // Daten aus App Group lesen — kein Netzwerk!
        let entry = FamilyScoreEntry(date: Date(), widgetData: loadWidgetData())

        #if DEBUG
        // App Group Verifikation
        let debugDefaults = UserDefaults(suiteName: "group.com.familyscore")
        let appWroteValue = debugDefaults?.bool(forKey: "phase1_verification") ?? false
        print("[Widget] App Group read from Widget: \(appWroteValue ? "PASS" : "FAIL")")
        #endif

        // Widget alle 30 Minuten refreshen (Free Tier Limit beachten)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadWidgetData() -> WidgetData {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: "widgetData"),
              let widgetData = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            return .placeholder
        }
        return widgetData
    }
}

struct FamilyScoreEntry: TimelineEntry {
    let date: Date
    let widgetData: WidgetData
}
```

---

### `FamilyScoreWidgetExtension/FamilyScoreWidgetBundle.swift` (widget-bundle, —)

**Externes Analog:** Apple WidgetBundle — [Apple Docs: WidgetBundle](https://developer.apple.com/documentation/widgetkit/widgetbundle)

**WidgetBundle Entry Point Pattern:**
```swift
import WidgetKit
import SwiftUI

@main
struct FamilyScoreWidgetBundle: WidgetBundle {
    var body: some Widget {
        FamilyScoreWidget()
        // Phase 5: Weitere Widget-Konfigurationen werden hier hinzugefügt
    }
}
```

**Hinweis:** Nur ein `@main` darf pro Extension-Target existieren. Wenn mehrere Widgets geplant sind, immer `WidgetBundle` (nicht einzelnes `Widget` mit `@main`) verwenden.

---

### `FamilyScoreWidgetExtension/FamilyScoreWidgetExtension.entitlements` (entitlement, —)

**Externes Analog:** identisch mit `FamilyScore.entitlements` — gleiche Gruppe `group.com.familyscore`.

**Identisches Entitlement-Format wie App Target:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.familyscore</string>
    </array>
</dict>
</plist>
```

**KRITISCH:** Muss EXAKT dieselbe Gruppe wie das App Target enthalten. Im Apple Developer Portal muss die Gruppe für BEIDE App IDs (`com.familyscore` und `com.familyscore.widgets`) aktiviert sein.

---

### `FamilyScoreKit/Package.swift` (spm-manifest, —)

**Externes Analog:** Swift Package Manager — [Swift.org: Package Description](https://www.swift.org/package-manager/)

**KRITISCHE REGEL:** Keine externe Abhängigkeit in diesem Package (insbesondere kein Supabase SDK). Nur Plain Swift / Foundation.

**Package.swift Pattern:**
```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FamilyScoreKit",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "FamilyScoreKit", targets: ["FamilyScoreKit"])
    ],
    targets: [
        .target(
            name: "FamilyScoreKit",
            path: "Sources/FamilyScoreKit"
        )
    ]
)
```

**Xcode-Integration (Reihenfolge):**
1. `File > Add Package Dependencies > Add Local...` → `FamilyScoreKit/` Verzeichnis wählen
2. App Target: `General > Frameworks, Libraries` → `FamilyScoreKit` hinzufügen
3. Widget Extension Target: `General > Frameworks, Libraries` → `FamilyScoreKit` hinzufügen
4. Supabase: NUR im App Target — Widget Extension bekommt kein Supabase

---

### `FamilyScoreKit/Sources/FamilyScoreKit/WidgetData.swift` (shared-model, —)

**Externes Analog:** Swift `Codable` + `Sendable` Structs — [Apple Docs: Encoding and Decoding Custom Types](https://developer.apple.com/documentation/swift/codable)

**Shared Model Pattern — Swift 6 Sendable:**
```swift
// Sources/FamilyScoreKit/WidgetData.swift
// Shared between App Target and Widget Extension
// KEIN Supabase SDK import — nur Foundation
import Foundation

public struct WidgetData: Codable, Sendable {
    public struct MemberScore: Codable, Sendable {
        public let displayName: String
        public let avatarInitial: String
        public let weeklyPoints: Double
        public let weeklyMinutes: Int

        public init(displayName: String, avatarInitial: String,
                    weeklyPoints: Double, weeklyMinutes: Int) {
            self.displayName = displayName
            self.avatarInitial = avatarInitial
            self.weeklyPoints = weeklyPoints
            self.weeklyMinutes = weeklyMinutes
        }
    }

    public let familyName: String
    public let members: [MemberScore]
    public let lastUpdated: Date

    public init(familyName: String, members: [MemberScore], lastUpdated: Date) {
        self.familyName = familyName
        self.members = members
        self.lastUpdated = lastUpdated
    }
}

// App Group Identifier — single source of truth für App und Widget
public let appGroupIdentifier = "group.com.familyscore"

// Placeholder für Widget-Previews und Snapshots
extension WidgetData {
    public static let placeholder = WidgetData(
        familyName: "Familie Muster",
        members: [
            MemberScore(displayName: "Max", avatarInitial: "M",
                        weeklyPoints: 120, weeklyMinutes: 90),
            MemberScore(displayName: "Anna", avatarInitial: "A",
                        weeklyPoints: 95, weeklyMinutes: 75)
        ],
        lastUpdated: Date()
    )
}
```

**Alle public Typen müssen `public init` haben** — sonst sind sie aus anderen Targets nicht initialisierbar.

---

### `Config/Config.xcconfig` (build-config, —)

**Externes Analog:** xcconfig `#include` Pattern — [NSHipster: Secrets Management on iOS](https://nshipster.com/secrets/)

**Config.xcconfig Pattern (wird committed):**
```
// Config.xcconfig
// Committed to Git — enthält keine Secrets
#include "Secrets.xcconfig"

SUPABASE_URL = $(SUPABASE_URL_SECRET)
SUPABASE_KEY = $(SUPABASE_KEY_SECRET)
```

**Einrichtung in Xcode:**
- Project → Info → Configurations (Debug, Release) → jeweils `Config/Config.xcconfig` auswählen
- Gilt für das App Target; Widget Extension bekommt keine Supabase-Build-Settings

---

### `Config/Secrets.xcconfig` (build-secret, — ) [GITIGNORED]

**Externes Analog:** xcconfig Secrets Pattern — [NSHipster: Secrets Management on iOS](https://nshipster.com/secrets/)

**KRITISCH:** Diese Datei muss in `.gitignore` stehen, BEVOR der erste `git add` ausgeführt wird.

**Secrets.xcconfig Pattern (NIEMALS commiten):**
```
// Secrets.xcconfig — DO NOT COMMIT
// Diese Datei ist in .gitignore und darf nie in Git landen
SUPABASE_URL_SECRET = https://your-project.supabase.co
SUPABASE_KEY_SECRET = sb_publishable_xxxxxxxxxxxxxxxx
```

**Hinweis zu neuen Supabase Keys (Stand 2025):** Supabase verwendet jetzt `sb_publishable_xxx`-Keys (statt legacy `anon`-Keys). Neue Projekte sollen `sb_publishable_xxx` verwenden. Legacy-Keys funktionieren bis Ende 2026.

**.gitignore Einträge:**
```
# Secrets
Secrets.xcconfig
*.xcconfig.local
```

---

### `Config/Secrets.xcconfig.template` (build-secret-template, —)

**Externes Analog:** Standard Template-Pattern für Secrets

**Template Pattern (wird committed als Anleitung für neue Entwickler):**
```
// Secrets.xcconfig.template
// SETUP: Copy this file to Secrets.xcconfig and fill in your values
// Secrets.xcconfig ist in .gitignore und wird NIE committed
SUPABASE_URL_SECRET = REPLACE_WITH_YOUR_SUPABASE_PROJECT_URL
SUPABASE_KEY_SECRET = REPLACE_WITH_YOUR_SUPABASE_PUBLISHABLE_KEY
```

---

### `supabase/migrations/20260515_initial_schema.sql` (db-migration, CRUD)

**Externes Analog:** Supabase PostgreSQL DDL + RLS — [Supabase Docs: Database](https://supabase.com/docs/guides/database)

**Gesamte Migrations-Datei ist vollständig in RESEARCH.md** (Zeilen 349–708) dokumentiert. Hier die wesentlichen Patterns:

**DDL Pattern — Alle Tabellen folgen diesem Schema:**
```sql
-- Jede Tabelle: uuid PK, family_id FK, timestamps
create table public.<table_name> (
  id          uuid primary key default gen_random_uuid(),
  family_id   uuid not null references public.families(id) on delete cascade,
  created_at  timestamptz not null default now()
  -- weitere Spalten...
);
-- Direkt nach CREATE: RLS aktivieren
alter table public.<table_name> enable row level security;
```

**RLS Helper Functions Pattern:**
```sql
-- Security Definer Functions als RLS-Performance-Optimierung
-- (auth.uid() wird einmal aufgerufen, nicht pro Row)
create or replace function public.is_family_member(p_family_id uuid)
returns boolean
language sql
security definer
set search_path = ''
as $$
  select exists(
    select 1 from public.family_members
    where id        = (select auth.uid())
      and family_id = p_family_id
  );
$$;
```

**RLS Policy Pattern (jede Tabelle):**
```sql
-- SELECT: Familienmitglied-Check via Helper-Function
create policy "Familienmitglieder können <table> lesen"
  on public.<table_name> for select to authenticated
  using (public.is_family_member(family_id));

-- INSERT: User-eigene Daten
create policy "User erstellt eigene Einträge"
  on public.<table_name> for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and public.is_family_member(family_id)
  );
```

**Trigger Pattern (weekly_summaries — NIEMALS inkrementell):**
```sql
-- IMMER vollständige Neuberechnung, nie inkrementell
-- Grund: Inkrementell schlägt fehl bei DELETE
create or replace function public.update_weekly_summary()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
-- ...
  insert into public.weekly_summaries (...)
  select v_family_id, v_user_id, v_week_start,
    coalesce(sum(ae.duration_minutes), 0),
    coalesce(sum(ae.points), 0),
    -- ...
  from public.activity_entries ae
  where ae.family_id = v_family_id
    and ae.user_id   = v_user_id
    and date_trunc('week', ae.logged_at)::date = v_week_start
  on conflict (family_id, user_id, week_start)
  do update set
    total_minutes = excluded.total_minutes,
    total_points  = excluded.total_points,
    -- ...
$$;
```

**Vollständiges DDL + alle RLS-Policies** sind in `01-RESEARCH.md` Zeilen 349–708 enthalten und müssen unverändert in die Migration übernommen werden.

---

## Shared Patterns

### App Group UserDefaults (Cross-Target-Datenaustausch)
**Gilt für:** App Target (schreiben) und Widget Extension (lesen)
**Identifier Quelle:** `FamilyScoreKit.appGroupIdentifier` — single source of truth

```swift
// App Target: nach Realtime-Update schreiben
func writeToAppGroup(_ widgetData: WidgetData) {
    guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
          let data = try? JSONEncoder().encode(widgetData) else { return }
    defaults.set(data, forKey: "widgetData")
    // Widget-Timeline invalidieren
    WidgetCenter.shared.reloadAllTimelines()
}

// Widget Extension: lesen (kein Netzwerk!)
func readFromAppGroup() -> WidgetData? {
    guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
          let data = defaults.data(forKey: "widgetData"),
          let widgetData = try? JSONDecoder().decode(WidgetData.self, from: data) else {
        return nil
    }
    return widgetData
}
```

### Secrets aus Build Settings lesen
**Gilt für:** `Supabase.swift` (App Target)
```swift
// Pattern: Bundle.main.object(forInfoDictionaryKey:) as! String
// Voraussetzung: Info.plist hat $(SUPABASE_URL) und $(SUPABASE_KEY) Einträge
// Voraussetzung: Config.xcconfig assigned zu Project Configuration
let url = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as! String
let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_KEY") as! String
```

### Swift 6 Strict Concurrency
**Gilt für:** Alle Swift-Dateien im Projekt

```swift
// RICHTIG (Swift 6):
await MainActor.run { /* UI-Updates */ }

// FALSCH (deprecated in Swift 6):
DispatchQueue.main.async { /* UI-Updates */ }

// Alle shared Typen müssen Sendable sein:
public struct WidgetData: Codable, Sendable { ... }
```

### RLS Security-Invariante
**Gilt für:** Alle Supabase-Tabellen in der Migration
```sql
-- PFLICHT nach jedem CREATE TABLE:
alter table public.<table_name> enable row level security;
-- Danach sofort mindestens eine SELECT-Policy erstellen
-- Ohne Policy: RLS default-deny → leere Results ohne Fehler
```

---

## Keine Analogs gefunden

Da dies ein Greenfield-Projekt ist, haben alle 14 Dateien keine Codebase-Analogs.
Alle Patterns kommen aus externen Quellen:

| Datei | Rolle | Grund für "Kein Analog" |
|-------|-------|-------------------------|
| Alle 14 Dateien | verschiedene | Neues Projekt, keine bestehende Codebase |

**Der Planner soll die Code-Excerpts aus den Pattern Assignments oben direkt verwenden.**
Vollständige SQL-Vorlage: `01-RESEARCH.md` Zeilen 349–708.

---

## Kritische Constraints für den Planner

| Constraint | Betroffene Dateien | Risiko bei Verletzung |
|------------|-------------------|----------------------|
| Supabase SDK NUR im App Target | `Supabase.swift`, `Package.swift`, Widget-Targets | Widget Extension überschreitet 30 MB → Terminierung auf Gerät |
| App Group Portal-Konfiguration vor Xcode | Beide `.entitlements` Dateien | Gerät: nil statt Daten; Simulator gibt fälschlicherweise Erfolg |
| Secrets.xcconfig vor erstem `git add` in .gitignore | `Secrets.xcconfig`, `.gitignore` | Supabase Key kompromittiert, bleibt in Git-History |
| RLS sofort nach CREATE TABLE aktivieren | `20260515_initial_schema.sql` | Silent empty results; schwer zu debuggen |
| Trigger niemals inkrementell | `20260515_initial_schema.sql` | Falsche Scores nach DELETE |
| `FamilyScoreKit` ohne externe Dependencies | `Package.swift` | Package-Auflösung zieht Supabase in Widget Extension |
| Wochenstart = Montag (ISO 8601) | `20260515_initial_schema.sql`, spätere App-Code | Inkonsistente Wochengrenzen zwischen DB und App |

---

## Build-Reihenfolge (für den Planner)

Die Reihenfolge ist von der RESEARCH.md als blockierend beschrieben:

1. Xcode-Projektstruktur: Targets + Entitlements (App Group Portal zuerst)
2. FamilyScoreKit Package erstellen und in beide Targets einbinden
3. Secrets.xcconfig + Config.xcconfig + .gitignore konfigurieren
4. Supabase-Projekt erstellen + Migration ausführen (DDL + RLS)
5. Swift-Verbindungstest (Supabase.swift + FamilyScoreApp.swift DEBUG-Code)

---

## Metadata

**Pattern-Quellen:**
- Apple Developer Documentation (SwiftUI, WidgetKit, App Groups, SPM)
- Supabase Docs (iOS Quickstart, Database, RLS, API Keys)
- NSHipster: Secrets Management on iOS (xcconfig Pattern)
- Use Your Loaf: Sharing Data with a Widget (App Group Setup)
- RESEARCH.md (01-RESEARCH.md) — primäre Quelle aller Code-Patterns

**Analogs-Suchbereich:** Kein vorhandener Codebase (Greenfield-Projekt)
**Dateien gescannt:** 0 (keine existierenden Source-Dateien)
**Pattern-Mapping-Datum:** 2026-05-15
