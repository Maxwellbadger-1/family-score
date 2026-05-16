# Phase 4: Activity Logging & Dashboard — Research

**Recherchiert:** 2026-05-16
**Domain:** SwiftUI Ring-Visualisierung, Supabase RPC-Aggregation, Activity-Logging, Swift Charts
**Konfidenz:** HIGH (Kern-Stack), MEDIUM (Timer-Persistenz-Details)

---

## Zusammenfassung

Phase 4 liefert den vollständigen Core-Loop der App: Aktivitäten erfassen (Timer + retroaktiv), drei konzentrische Ringe nach Apple-Fitness-Stil, Wochenzusammenfassung per Swift Charts und einen chronologischen Verlauf mit Swipe-to-Delete. Der UI-Vertrag ist durch `04-UI-SPEC.md` vollständig festgelegt — keine Designentscheidungen offen.

Die technisch kritischste Abhängigkeit ist das **Score-Berechnungs-Prinzip**: Scores entstehen **ausschließlich** als `SUM()` auf `activity_entries` — niemals als akkumulierter Wert auf Client-Seite. Das bestehende Schema aus Phase 1 enthält bereits den `update_weekly_summary`-Trigger, der `weekly_summaries` nach jedem INSERT/DELETE atomisch aktualisiert. Phase 4 liest diese Tabelle und braucht zusätzlich eine RPC für den **heutigen** Tagesstand (der Trigger pflegt nur Wochen, nicht Tage).

Die Ringe werden via `Circle().trim().stroke()` gebaut — kein Canvas, kein SwiftUI Charts. Swift Charts kommt ausschließlich für die Wochenbilanz zum Einsatz (BarMark, horizontal gestapelt oder nebeneinander per Member). `@Observable` ist iOS 17+; das Projekt hat iOS 16.0 Minimum und nutzt durchgehend `ObservableObject + @Published`.

**Primäre Empfehlung:** `ActivityService` als `@MainActor ObservableObject` mit Protocol-basiertem Mock. Timer-Persistenz via `timerStartedAt: Date?` in `@AppStorage`. Score-Aggregation: Tagesscore via RPC `get_today_score`, Wochendaten aus `weekly_summaries`. Optimistic UI: lokale Array-Mutation vor Supabase-Antwort, Rollback bei Fehler.

---

<phase_requirements>
## Phase Requirements

| ID | Beschreibung | Research-Grundlage |
|----|-------------|-------------------|
| LOG-01 | User kann eine Aktivität mit Timer erfassen (Start/Stop) — Zeit wird automatisch berechnet | Timer als `timerStartedAt: Date?` + `@AppStorage`-Persistenz; `TimeInterval` = `Date.now - timerStartedAt` beim Stop |
| LOG-02 | User kann eine Aktivität retroaktiv eintragen: Kategorie + Dauer in Minuten + optionaler Titel | Sheet mit `.pickerStyle(.wheel)` für Dauer; INSERT in `activity_entries` mit `duration_minutes` + `logged_at = now()` |
| LOG-03 | User kann einem Eintrag einen freien Titel geben (z.B. "Küche geputzt") | `TextField` im Sheet, mapped auf `activity_entries.title`; optional |
| LOG-04 | User kann Einträge für Kinder-Profile erstellen (Eltern-managed) | INSERT mit `user_id = childProfile.id`; RLS-Bypass via `SECURITY DEFINER` RPC (`create_activity_for_child`); Eltern müssen `is_family_admin` oder explizit `adult` mit Kind-Verwaltungsrecht sein |
| LOG-05 | User kann einen Eintrag löschen (nur eigene, Admins dürfen alle) | RLS-Policies in Phase 1 bereits korrekt: `user_id = auth.uid()` für Selbst-Löschen; `is_family_admin(family_id)` für Admin-Löschen |
| LOG-06 | Aktivitäten werden einer von 4 Kategorien zugeordnet | `category_config`-IDs aus DB laden; Mapping: Haushalt/Besorgungen/Arbeit = Pflicht-Ring; Hobby/Freizeit = Freizeit-Ring |
| DASH-01 | Hauptansicht zeigt persönliche Ringe für heute: Pflicht, Freizeit, Score | `Circle().trim()` in ZStack; Daten via RPC `get_today_score`; Animation `.spring(response: 0.6, dampingFraction: 0.75)` |
| DASH-02 | Familienvergleich zeigt alle Mitglieder nebeneinander mit heutiger Bilanz | Mini-Ring + Name + Punkte pro Member-Row; Daten via RPC `get_family_today_scores`; serverseitig aggregiert |
| DASH-03 | Wochenbilanz zeigt Pflicht vs. Freizeit alle Mitglieder + Wochensieger | Query auf `weekly_summaries`; `by_category` JSONB aufschlüsseln; Swift Charts BarMark |
| DASH-04 | Gesamt-Statistiken: alle Stunden und Punkte seit App-Start pro Person | Einfache `SELECT SUM()` auf `activity_entries` ohne Datumsfilter; kein neues Schema nötig |
| DASH-05 | Aktivitäts-Feed: chronologische Liste aller Einträge der Familie heute | `SELECT * FROM activity_entries WHERE family_id = ? AND date(logged_at) = today ORDER BY logged_at DESC`; gefiltert per RPC oder direktem Query |
| SCORE-01 | Konfigurierbare Punkte-Multiplikatoren pro Kategorie | Phase 4: Multiplikator fix 1,0 (UI-SPEC); `category_config.point_weight` vorhanden, aber Konfiguration in Phase 6 |
| SCORE-02 | Score als Summe aller Aktivitäts-Punkte (append-only) | Schema garantiert: kein `total_score`-Spalte; `activity_entries.points = duration_minutes × point_weight` beim INSERT berechnet |
| SCORE-03 | Score täglich und wöchentlich aggregiert in UI | Täglich: RPC `get_today_score`; Wöchentlich: `weekly_summaries` (Trigger aus Phase 1); beide Quellen serverseitig |
</phase_requirements>

---

## Project Constraints (aus CLAUDE.md)

| Direktive | Auswirkung auf Phase 4 |
|-----------|----------------------|
| Score NIEMALS als mutabler Wert speichern | Kein lokales Akkumulieren; Ringe spiegeln RPC-Ergebnis + optimistic delta |
| Supabase SDK NUR im Hauptapp-Target | `ActivityService`, alle RPC-Calls, `category_config`-Queries: nur in `FamilyScore.app`-Target |
| RLS immer aktivieren | Activity_entries-Policies aus Phase 1 bereits aktiv; Kinder-INSERT braucht `SECURITY DEFINER` RPC |
| RLS nur mit echtem JWT testen | Verification-Checkpoint auf echtem Gerät mit eingeloggtem User |
| iOS 16.0 Minimum | `@Observable` verboten; `ObservableObject + @Published`; `.sheet` mit `presentationDetents` (iOS 16+) |
| Swift 6, Xcode 16 | `@MainActor` auf Services; Sendable für Datenmodelle |
| 3 Taps Maximum | FAB → Sheet → Speichern = exakt 3 Taps (UI-SPEC erfüllt das) |
| Apple Health/Fitness Ästhetik | Ringe exakt nach Ring Layout Contract in `04-UI-SPEC.md`; keine Drittanbieter-Charts |
| Realtime stirbt im Hintergrund | Betrifft Phase 5; in Phase 4 nur REST-Fetch (kein Realtime-Subscription) |
| FamilyScoreKit für geteilten Code | WidgetData-Struct für Score-Snapshot; keine Supabase-Imports in FamilyScoreKit |

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Ring-Visualisierung | App (SwiftUI View) | — | `Circle().trim()` + `ZStack`; rein deklarativ, keine DB-Logik in der View |
| Tagesscore-Aggregation | Supabase DB (RPC) | App (ActivityService) | `SUM()` server-seitig ist Projekt-Architekturgesetz |
| Wochenscore-Aggregation | Supabase DB (weekly_summaries) | App (ActivityService) | Trigger aus Phase 1 aktualisiert Tabelle bei jedem INSERT/DELETE automatisch |
| Aktivität erstellen (own) | App (ActivityService) | Supabase DB (RLS) | Client sendet INSERT; RLS prüft `user_id = auth.uid()` |
| Aktivität erstellen (Kind) | Supabase DB (SECURITY DEFINER RPC) | App (ActivityService) | RLS erlaubt kein `user_id ≠ auth.uid()` bei direktem INSERT; RPC umgeht das kontrolliert |
| Aktivität löschen | Supabase DB (RLS) | App (ActivityService) | Zwei Policies: eigene Einträge / Admin; App ruft `delete().eq("id")` auf |
| Timer-Zustand | App (AppStorage) | — | `timerStartedAt: Date?` persistent; überleben Hintergrund und Re-Launch |
| Kategorie-Konfiguration | Supabase DB (category_config) | App (Cache in ActivityService) | Pro Familie konfigurierbar; für Phase 4 Read-Only, Mutation erst Phase 6 |
| Optimistic UI | App (ActivityService) | — | Lokale Array-Mutation vor Supabase-Antwort; Rollback bei Error |
| Weekly Wochensieger | App (ActivityService) | Supabase DB (weekly_summaries) | Sorting nach `total_points` client-seitig nach Datenabruf |
| Swift Charts Wochenbilanz | App (SwiftUI View) | — | Keine Chart-Logik in Service; View empfängt fertige Daten |

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| supabase-swift | 2.46.0 | DB-Queries, RPC-Calls, DELETE | Bereits installiert; einziges offizielles Swift-SDK |
| SwiftUI (native) | iOS 16+ | Alle UI-Komponenten | Projektvorgabe; keine Third-Party UI-Libs |
| Swift Charts | iOS 16+ | Wochenbilanz-BarChart | Native Apple-Framework; kein externer Chart-Import nötig |
| Foundation | System | Timer-Datum, DateFormatter | System-Framework |
| XCTest | System | Unit Tests via MockActivityService | Bewährtes Muster aus Phase 2 |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| FamilyScoreKit | Local Package | WidgetData-Snapshot für Phase 5 | `ActivityService` schreibt nach Fetch den Snapshot in App Group |
| AuthenticationServices | System | — | Nicht in Phase 4 gebraucht |

### Alternativen (abgelehnt)

| Statt | Könnte man | Warum abgelehnt |
|-------|-----------|-----------------|
| `Circle().trim()` | Canvas-API | Canvas ist komplexer, braucht `GraphicsContext`; `.trim()` ist idiomatischer und iOS 16-kompatibel |
| Swift Charts | Third-Party (Charts.swift) | Keine externen Dependencies; Swift Charts ist seit iOS 16 verfügbar und ausreichend |
| `ObservableObject` | `@Observable` | `@Observable` erfordert iOS 17+; Projekt hat iOS 16 Minimum |
| `SECURITY DEFINER` RPC für Kinder | Service-Role-Key im Client | Service-Role-Key darf nie im iOS-Bundle liegen |

---

## Architecture Patterns

### System-Architektur (Datenfluss Phase 4)

```
User-Interaction (FAB / Timer / Swipe-Delete)
        │
        ▼
ActivityLogSheet / ActivityListView (SwiftUI)
        │  @Published bindings
        ▼
ActivityService (@MainActor ObservableObject)
        │                           │
        │ INSERT / DELETE           │ SELECT / RPC
        ▼                           ▼
supabase.from("activity_entries")  supabase.rpc("get_today_score")
        │                           supabase.from("weekly_summaries")
        │ DB Trigger (Phase 1)      supabase.from("category_config")
        ▼
weekly_summaries (auto-updated)
        │
        ▼ (App liest zurück)
ActivityService.weeklyScores[]
        │
        ▼
DashboardView (Ringe) + WeekSummaryView (Charts) + ActivityFeedView (List)
        │
        ▼ (nach Fetch)
WidgetData.snapshot → App Group UserDefaults
        │
        ▼ (Phase 5: WidgetCenter.shared.reloadAllTimelines())
```

### Empfohlene Projektstruktur (Phase 4 Ergänzungen)

```
FamilyScore/
├── Services/
│   ├── ActivityService.swift        # ObservableObject, alle CRUD + RPC Calls
│   └── AuthService.swift            # bestehend aus Phase 2
├── Models/
│   ├── ActivityEntry.swift          # Codable, Decodable
│   ├── CategoryConfig.swift         # Codable
│   ├── DayScore.swift               # Result-Typ für get_today_score RPC
│   └── AppState.swift               # bestehend
├── Views/
│   ├── Dashboard/
│   │   ├── DashboardView.swift      # Tab 1: Ringe + Wochenbilanz
│   │   ├── RingClusterView.swift    # drei konzentrische Ringe
│   │   ├── SingleRingView.swift     # eine Ringe-Komponente
│   │   └── WeekSummaryView.swift    # Swift Charts BarChart
│   ├── ActivityLog/
│   │   ├── ActivityListView.swift   # Tab 2: Verlauf
│   │   ├── ActivityRowView.swift    # List-Zeile
│   │   └── ActivityLogSheet.swift  # Modal: Kategorie + Dauer + Notiz
│   └── Auth/                        # bestehend aus Phase 2
FamilyScoreTests/
├── ActivityServiceTests.swift       # Wave 0 Stubs
└── Mocks/
    ├── MockAuthService.swift        # bestehend
    └── MockActivityService.swift    # neu in Wave 0
```

---

## Pattern 1: Konzentrische Ringe (Circle + trim + ZStack)

**Was:** Drei `Circle()`-Views mit `.trim(from: 0, to: progress)`, in `ZStack` verschachtelt mit unterschiedlichen Frame-Größen.
**Wann:** Immer — kein Canvas, kein alternatives Approach.

```swift
// Source: Verified via WebSearch + official SwiftUI docs pattern
// iOS 16 kompatibel — kein API nach iOS 16

struct SingleRingView: View {
    let progress: Double          // 0.0 – 1.0+ (Überlauf erlaubt per UI-SPEC)
    let color: Color
    let lineWidth: CGFloat = 20   // UI-SPEC: 20pt fix

    var body: some View {
        ZStack {
            // Track (Hintergrund-Arc)
            Circle()
                .stroke(color.opacity(0.15), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            // Progress-Arc
            Circle()
                .trim(from: 0, to: min(progress, 1.0))   // erste Runde
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))             // 12-Uhr-Start

            // Zweite Runde (Überlauf > 100%)
            if progress > 1.0 {
                Circle()
                    .trim(from: 0, to: progress - 1.0)
                    .stroke(color.opacity(0.6), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
    }
}

struct RingClusterView: View {
    let dutyProgress: Double    // Pflicht-Ring (rot, außen)
    let leisureProgress: Double // Freizeit-Ring (grün, mitte)
    let scoreProgress: Double   // Score-Ring (blau, innen)
    let totalScore: Int

    // Ringgrößen: außen → innen, 8pt Abstand (UI-SPEC)
    // lineWidth = 20pt, Gap = 8pt → nächster Ring 2*(20+8) = 56pt kleiner
    private let outerDiameter: CGFloat = 280
    private let gap: CGFloat = 8
    private let lineWidth: CGFloat = 20

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

            // Zentrum: Tagesscore
            VStack(spacing: 2) {
                Text("\(totalScore)")
                    .font(.system(size: 34, weight: .semibold))  // Display
                    .monospacedDigit()
                Text("Punkte heute")
                    .font(.system(size: 13))                       // Label
                    .foregroundStyle(.secondary)
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.75), value: dutyProgress)
        .animation(.spring(response: 0.6, dampingFraction: 0.75), value: leisureProgress)
        .animation(.spring(response: 0.6, dampingFraction: 0.75), value: scoreProgress)
    }
}
```

**Accessibility (UI-SPEC):**
```swift
SingleRingView(...)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Pflicht-Ring: \(Int(dutyProgress * 60)) von 60 Punkten erreicht (\(Int(dutyProgress * 100))%)")
```

---

## Pattern 2: Supabase RPC — Tagesscore (neue Migration nötig)

**Was:** PostgreSQL-Funktion `get_today_score`, die Tagesdaten direkt aus `activity_entries` aggregiert (der Phase-1-Trigger pflegt nur `weekly_summaries`).
**Wann:** Beim Laden von DashboardView und nach jedem INSERT.

```sql
-- Neue Migration: 20260516_phase4_rpcs.sql
-- Tagesscore für den aktuellen User (und optional für Kind-Profile der Familie)

CREATE OR REPLACE FUNCTION public.get_today_score(p_user_id uuid DEFAULT NULL)
RETURNS TABLE (
    duty_minutes   int,
    duty_points    numeric,
    leisure_minutes int,
    leisure_points  numeric,
    total_points   numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid;
    v_today   date;
BEGIN
    v_user_id := COALESCE(p_user_id, (SELECT auth.uid()));
    v_today   := CURRENT_DATE;  -- Timezone-Hinweis: DB-Timezone muss mit Client übereinstimmen

    RETURN QUERY
    SELECT
        COALESCE(SUM(CASE WHEN cc.name IN ('Haushalt','Besorgungen','Arbeit/Schule')
                         THEN ae.duration_minutes ELSE 0 END), 0)::int AS duty_minutes,
        COALESCE(SUM(CASE WHEN cc.name IN ('Haushalt','Besorgungen','Arbeit/Schule')
                         THEN ae.points ELSE 0.0 END), 0.0) AS duty_points,
        COALESCE(SUM(CASE WHEN cc.name = 'Hobby/Freizeit'
                         THEN ae.duration_minutes ELSE 0 END), 0)::int AS leisure_minutes,
        COALESCE(SUM(CASE WHEN cc.name = 'Hobby/Freizeit'
                         THEN ae.points ELSE 0.0 END), 0.0) AS leisure_points,
        COALESCE(SUM(ae.points), 0.0) AS total_points
    FROM public.activity_entries ae
    JOIN public.category_config cc ON cc.id = ae.category_id
    WHERE ae.user_id = v_user_id
      AND ae.logged_at::date = v_today;
END;
$$;
```

**Swift-Aufruf:**
```swift
// Source: supabase.com/docs/reference/swift/rpc (VERIFIED)
struct DayScore: Decodable {
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

let score: [DayScore] = try await supabase
    .rpc("get_today_score")
    .execute()
    .value
```

---

## Pattern 3: Aktivität einfügen (eigener Eintrag)

```swift
// Source: supabase.com/docs/reference/swift/insert (VERIFIED)
struct NewActivityEntry: Encodable {
    let familyId: UUID
    let userId: UUID
    let categoryId: UUID
    let durationMinutes: Int
    let points: Double     // = durationMinutes × point_weight (client berechnet, DB speichert)
    let title: String?
    // logged_at: server default (now())

    enum CodingKeys: String, CodingKey {
        case familyId = "family_id"
        case userId = "user_id"
        case categoryId = "category_id"
        case durationMinutes = "duration_minutes"
        case points
        case title
    }
}

struct ActivityEntry: Codable, Identifiable {
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

// Im ActivityService:
func logActivity(categoryId: UUID, durationMinutes: Int, title: String?) async throws {
    guard let user = authService.currentUser,
          let familyId = currentFamilyId else { throw ActivityError.notAuthenticated }

    let weight = categories.first(where: { $0.id == categoryId })?.pointWeight ?? 1.0
    let entry = NewActivityEntry(
        familyId: familyId,
        userId: user.id,
        categoryId: categoryId,
        durationMinutes: durationMinutes,
        points: Double(durationMinutes) * weight,
        title: title
    )

    // Optimistic: lokal vor DB-Antwort hinzufügen
    let optimisticId = UUID()
    let optimisticEntry = ActivityEntry(id: optimisticId, ...)
    todayEntries.insert(optimisticEntry, at: 0)
    refreshLocalRingProgress()  // Punkte sofort anzeigen

    do {
        let saved: ActivityEntry = try await supabase
            .from("activity_entries")
            .insert(entry)
            .select()
            .single()
            .execute()
            .value
        // Optimistischen Eintrag durch echten ersetzen
        todayEntries.removeAll { $0.id == optimisticId }
        todayEntries.insert(saved, at: 0)
    } catch {
        // Rollback
        todayEntries.removeAll { $0.id == optimisticId }
        refreshLocalRingProgress()
        throw error
    }
}
```

---

## Pattern 4: Kind-Eintrag (SECURITY DEFINER RPC)

**Problem:** RLS-Policy `User erstellt eigene Eintraege` prüft `user_id = auth.uid()`. Ein Elternteil kann deshalb nicht direkt `user_id = kindId` einfügen. [VERIFIED: Supabase RLS-Dokumentation + GitHub Discussion #36295]

**Lösung:** `SECURITY DEFINER`-RPC, die die Beziehung Elternteil→Kind prüft, bevor sie den Eintrag einfügt.

```sql
-- Neue Migration
CREATE OR REPLACE FUNCTION public.create_activity_for_child(
    p_child_user_id  uuid,
    p_category_id    uuid,
    p_duration_min   int,
    p_points         numeric,
    p_title          text DEFAULT NULL
)
RETURNS public.activity_entries
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_parent_id uuid := (SELECT auth.uid());
    v_family_id uuid;
    v_result    public.activity_entries;
BEGIN
    -- Elternteil muss in derselben Familie sein und Admin oder Adult-Rolle haben
    SELECT family_id INTO v_family_id
    FROM public.family_members
    WHERE id = v_parent_id
      AND role IN ('admin', 'adult')
      AND family_id = (SELECT family_id FROM public.family_members WHERE id = p_child_user_id);

    IF v_family_id IS NULL THEN
        RAISE EXCEPTION 'Nicht berechtigt, Einträge für dieses Kind zu erstellen';
    END IF;

    INSERT INTO public.activity_entries
        (family_id, user_id, category_id, duration_minutes, points, title)
    VALUES
        (v_family_id, p_child_user_id, p_category_id, p_duration_min, p_points, p_title)
    RETURNING * INTO v_result;

    RETURN v_result;
END;
$$;
```

**Swift-Aufruf:**
```swift
struct ChildActivityParams: Encodable {
    let pChildUserId: UUID
    let pCategoryId: UUID
    let pDurationMin: Int
    let pPoints: Double
    let pTitle: String?

    enum CodingKeys: String, CodingKey {
        case pChildUserId = "p_child_user_id"
        case pCategoryId = "p_category_id"
        case pDurationMin = "p_duration_min"
        case pPoints = "p_points"
        case pTitle = "p_title"
    }
}

let result: ActivityEntry = try await supabase
    .rpc("create_activity_for_child", params: params)
    .execute()
    .value
```

---

## Pattern 5: Aktivität löschen

```swift
// Source: supabase.com/docs/reference/swift/delete (VERIFIED)
// RLS-Policies (Phase 1) entscheiden automatisch:
// - eigene Einträge: Policy "User loescht eigene Eintraege"
// - als Admin: Policy "Admin loescht alle Eintraege der Familie"
// Kein Swift-seitiger Role-Check nötig — DB lehnt unauthorisierte Deletes ab

func deleteActivity(id: UUID) async throws {
    // Optimistic: sofort aus Liste entfernen
    let backup = todayEntries
    todayEntries.removeAll { $0.id == id }
    refreshLocalRingProgress()

    do {
        try await supabase
            .from("activity_entries")
            .delete()
            .eq("id", value: id)
            .execute()
    } catch {
        // Rollback bei RLS-Fehler oder Netzwerkfehler
        todayEntries = backup
        refreshLocalRingProgress()
        throw error
    }
}
```

**Wichtig:** Das Supabase-Swift-SDK löscht nur Rows, die durch aktive SELECT-Policies sichtbar sind. Da `family_members` lesen können (`Familienmitglieder lesen alle Eintraege der Familie`), ist die DELETE-Policy korrekt adressierbar. [VERIFIED: supabase.com/docs/reference/swift/delete]

---

## Pattern 6: Timer-Implementierung

**Ansatz:** `timerStartedAt: Date?` in `@AppStorage` speichern. Timer-Anzeige via `TimeInterval = Date.now.timeIntervalSince(timerStartedAt)` live berechnen. Kein `Timer.publish()` der im Hintergrund stirbt.

```swift
// Im ActivityService (oder dediziertem TimerManager):
@AppStorage("timerStartedAt") private var timerStartedAtInterval: Double = 0
@AppStorage("timerCategoryId") private var timerCategoryIdString: String = ""

var timerIsRunning: Bool { timerStartedAtInterval > 0 }
var timerStartedAt: Date? {
    timerStartedAtInterval > 0 ? Date(timeIntervalSince1970: timerStartedAtInterval) : nil
}
var elapsedSeconds: TimeInterval {
    guard let start = timerStartedAt else { return 0 }
    return Date.now.timeIntervalSince(start)
}

func startTimer(categoryId: UUID) {
    timerStartedAtInterval = Date.now.timeIntervalSince1970
    timerCategoryIdString = categoryId.uuidString
}

func stopTimer(title: String?) async throws {
    guard let start = timerStartedAt,
          let categoryId = UUID(uuidString: timerCategoryIdString) else { return }
    let minutes = max(1, Int(Date.now.timeIntervalSince(start) / 60))
    timerStartedAtInterval = 0
    timerCategoryIdString = ""
    try await logActivity(categoryId: categoryId, durationMinutes: minutes, title: title)
}
```

**Live-Anzeige im View:**
```swift
// TimelineView aktualisiert jeden Sekunde (iOS 15+, kein Hintergrund-Problem)
// Alternativ: Timer.publish mit .onReceive, MUSS bei .background pausiert werden

@State private var displaySeconds: Int = 0
// In .task {} oder .onReceive(scenePhasePublisher):
// displaySeconds = Int(activityService.elapsedSeconds)
```

**Hintergrund-Verhalten:** Wenn App in den Hintergrund geht, wird keine Live-Aktualisierung der View benötigt — `timerStartedAt` ist persistent in UserDefaults. Beim Zurückkehren in den Vordergrund wird `elapsedSeconds` korrekt neu berechnet. Kein `BackgroundTask` nötig. [VERIFIED: bewährtes Pattern aus Hacking with Swift Forums, Apple Forums]

---

## Pattern 7: Swift Charts Wochenbilanz

**Was:** `BarMark` mit `.foregroundStyle(by:)` und `.position(by:)` für Member-Vergleich.
**iOS 16 Verfügbarkeit:** BarMark, LineMark, PointMark, AreaMark, RuleMark, RectangleMark alle iOS 16+. [VERIFIED: Apple Developer Docs]

```swift
// Source: avanderlee.com/swift-charts/bar-chart-creation (VERIFIED)
struct WeekMemberScore: Identifiable {
    let id = UUID()
    let memberName: String
    let category: String    // "Pflicht" oder "Freizeit"
    let minutes: Int
}

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
```

---

## Pattern 8: Activity Log Sheet (iOS 16 Half-Sheet)

**Was:** `.sheet` mit `presentationDetents([.medium])` — iOS 16 nativ, kein Third-Party.
[VERIFIED: donnywals.com/presenting-a-partially-visible-bottom-sheet-in-swiftui-on-ios-16]

```swift
// Source: VERIFIED iOS 16 API
.sheet(isPresented: $showingLogSheet) {
    ActivityLogSheet(activityService: activityService)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
}
```

**Dauer-Picker:**
```swift
// Wheel-Picker, 5-Minuten-Schritte, 5–240 min, Default 30 min (UI-SPEC)
Picker("Dauer", selection: $selectedDuration) {
    ForEach(Array(stride(from: 5, through: 240, by: 5)), id: \.self) { minutes in
        Text("\(minutes) min").tag(minutes)
    }
}
.pickerStyle(.wheel)
```

---

## Pattern 9: Swipe-to-Delete mit Bestätigung

```swift
// UI-SPEC: swipeActions (nicht onDelete), damit confirmationDialog korrekt funktioniert
// Source: SwiftUI Cookbook (Kodeco) — .swipeActions deaktiviert auto-synthesis von .onDelete
List(entries) { entry in
    ActivityRowView(entry: entry)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                entryToDelete = entry
                showDeleteConfirmation = true
            } label: {
                Label("Löschen", systemImage: "trash")
            }
        }
}
.confirmationDialog("Eintrag löschen", isPresented: $showDeleteConfirmation) {
    Button("Löschen", role: .destructive) {
        if let entry = entryToDelete {
            Task { try? await activityService.deleteActivity(id: entry.id) }
        }
    }
    Button("Abbrechen", role: .cancel) {}
} message: {
    Text("Dieser Eintrag wird dauerhaft gelöscht.")
}
```

---

## Pattern 10: Optimistic UI (State-Management)

**Prinzip:** Lokale Array-Mutation → UI-Update → async Supabase-Call → bei Fehler Rollback.
**Warum Value-Types:** `ActivityEntry` als `struct` (value type) in einem `@Published var todayEntries: [ActivityEntry]` — eine Änderung am Array oder Element triggers `objectWillChange`. [VERIFIED: SwiftUI @Published mit Structs — Standard-Muster]

```swift
// Im ActivityService
private var _todayEntries: [ActivityEntry] = [] {
    didSet { objectWillChange.send() }
}

// Ring-Progress aus lokalem Array berechnen — NIEMALS persistent akkumulieren
func refreshLocalRingProgress() {
    let categories = self.categories
    let dutyIds = Set(categories.filter { ["Haushalt","Besorgungen","Arbeit/Schule"].contains($0.name) }.map(\.id))
    let leisureIds = Set(categories.filter { $0.name == "Hobby/Freizeit" }.map(\.id))

    let dutyPts = _todayEntries.filter { dutyIds.contains($0.categoryId) }.reduce(0) { $0 + $1.points }
    let leisurePts = _todayEntries.filter { leisureIds.contains($0.categoryId) }.reduce(0) { $0 + $1.points }
    let totalPts = _todayEntries.reduce(0) { $0 + $1.points }

    // 60 pts = Ring full (UI-SPEC)
    dutyProgress = dutyPts / 60.0
    leisureProgress = leisurePts / 60.0
    scoreProgress = totalPts / 60.0
    totalScore = Int(totalPts)
}
```

---

## Don't Hand-Roll

| Problem | Nicht selbst bauen | Stattdessen | Warum |
|---------|-------------------|-------------|-------|
| Wochenbeginn (Montag) berechnen | Eigene Kalender-Arithmetik | PostgreSQL `date_trunc('week', ...)` — immer ISO-Montag [VERIFIED] | Edge Cases: Jahreswechsel, Schalttage |
| Punkte-Berechnung akkumulieren | `total_score`-Spalte + Inkrementierung | `SUM()` via `weekly_summaries` + RPC | Architekturgesetz; Inkonsistenz bei Race Conditions |
| Kinder-Permission-Check | Swift-seitig Role prüfen | `SECURITY DEFINER`-RPC | Role-Check muss atomisch mit INSERT sein; Client kann manipuliert werden |
| Hintergrund-Timer fortführen | `BackgroundTask` + UNNotification | `timerStartedAt: Date?` persistent + Neuberechnung bei Vordergrund | iOS Background-Limits; Start-Timestamp ist ausreichend |
| JSONB-Parsing für `by_category` | Eigener JSON-Parser | `Codable` struct mit `[String: CategoryBreakdown]` als `Dictionary` | Standard Swift JSON-Decoding handhabt das automatisch |

**Key Insight:** Komplexe Aggregationen gehören in PostgreSQL. Swift macht die Präsentation, nicht die Berechnung.

---

## Wichtige Pitfalls

### Pitfall 1: `date_trunc('week')` und Timezone

**Was geht schief:** `date_trunc('week', logged_at)` benutzt die DB-Timezone (UTC). Für einen User in UTC+2 ist Sonntag 23:00 Lokalzeit = Montag 01:00 UTC — der Eintrag landet in der falschen Woche.

**Warum:** PostgreSQL `date_trunc('week', timestamptz)` trunciert bezüglich der Session-Timezone, NICHT immer UTC. [CITED: postgresql.org/docs/current/functions-datetime.html]

**Wie vermeiden:**
```sql
-- Explizit Timezone mitgeben:
date_trunc('week', ae.logged_at AT TIME ZONE 'Europe/Berlin')::date
-- Oder: Supabase timezone auf 'Europe/Berlin' setzen
-- Für Phase 4: logged_at wird als "Jetzt" eingefügt — lokal korrekt, wenn
-- der Supabase-Projekt-Timezone auf Europe/Berlin eingestellt ist
```

**Warnung:** Für Phase 4 ist dies ein bekanntes Risiko, aber kein Blocker. Der Phase-1-Trigger `update_weekly_summary` nutzt `date_trunc('week', ...)` ohne explizite Timezone — das muss geprüft und ggf. migriert werden.

### Pitfall 2: `@AppStorage` und `UUID`

**Was geht schief:** `@AppStorage` unterstützt nur `String`, `Int`, `Double`, `Bool`, `Data`, `URL`. `UUID` direkt speichern schlägt fehl.

**Wie vermeiden:** `timerCategoryIdString: String` in `@AppStorage`, dann `UUID(uuidString:)` für die Verwendung.

### Pitfall 3: `delete()` ohne SELECT-Policy

**Was geht schief:** Supabase-Swift `delete()` löscht nur Rows, die durch SELECT-Policies sichtbar sind. Wenn keine SELECT-Policy existiert, kann nichts gelöscht werden — kein Fehler, aber auch keine Wirkung. [VERIFIED: supabase.com/docs/reference/swift/delete]

**Wie vermeiden:** Phase 1 hat `Familienmitglieder lesen alle Eintraege der Familie` — korrekt. Sicherstellen, dass der RLS-Test mit echtem JWT (nicht Dashboard) bestätigt.

### Pitfall 4: `@Published` mit Nested Value Types

**Was geht schief:** `@Published var entries: [ActivityEntry]` – wenn `ActivityEntry` eine Klasse (Reference Type) ist, wird `objectWillChange` nicht bei Eigenschafts-Änderungen der Elemente ausgelöst.

**Wie vermeiden:** `ActivityEntry` als `struct` (Value Type) implementieren. [VERIFIED: SwiftUI-Dokumentation + bekanntes Community-Pitfall]

### Pitfall 5: `.onDelete` vs `.swipeActions`

**Was geht schief:** Wenn sowohl `.onDelete` als auch `.swipeActions` auf demselben `ForEach` stehen, deaktiviert `.swipeActions` die automatische Delete-Synthese von `.onDelete`. Der Delete-Button erscheint aber `.onDelete` reagiert nicht mehr.

**Wie vermeiden:** Ausschließlich `.swipeActions` verwenden, `confirmationDialog` manuell implementieren. [VERIFIED: SwiftUI Cookbook, Kodeco]

### Pitfall 6: Punkte-Berechnung client-seitig bei Optimistic UI

**Was geht schief:** `refreshLocalRingProgress()` aus lokalen Daten berechnen ist OK für Optimistic UI. Wenn aber der endgültige Datenbankwert abweicht (z.B. durch Server-Default `point_weight`), stimmt die Ring-Anzeige nach dem Rollback nicht mehr.

**Wie vermeiden:** Nach erfolgreichem INSERT immer die `get_today_score`-RPC neu abrufen, um den authoritative Wert zu übernehmen. Optimistic Update ist nur temporär bis zur Server-Bestätigung.

### Pitfall 7: `SECURITY DEFINER` und `search_path`

**Was geht schief:** Ohne `SET search_path = ''` kann eine `SECURITY DEFINER`-Funktion anfällig für Path-Injection sein. [CITED: supabase.com/docs/guides/database/functions]

**Wie vermeiden:** Alle neuen RPCs mit `SET search_path = ''` und expliziten Schema-Prefixen (`public.activity_entries`) schreiben. Konvention aus Phase 1 beibehalten.

---

## Datenbankschema-Ergänzungen (Phase 4 Migration)

Die Phase-1-Migration ist vollständig. Phase 4 braucht **nur neue Funktionen**, keine neuen Tabellen:

```sql
-- Datei: supabase/migrations/20260516_phase4_rpcs.sql

-- 1. get_today_score(p_user_id uuid DEFAULT NULL) — siehe Pattern 2
-- 2. get_family_today_scores() — alle Mitglieder der Familie
-- 3. create_activity_for_child(...) — Kind-Eintrag via SECURITY DEFINER — siehe Pattern 4

-- get_family_today_scores: alle Mitglieder der eigenen Familie
CREATE OR REPLACE FUNCTION public.get_family_today_scores()
RETURNS TABLE (
    user_id        uuid,
    display_name   text,
    avatar_color   text,
    duty_points    numeric,
    leisure_points numeric,
    total_points   numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    RETURN QUERY
    SELECT
        fm.id AS user_id,
        fm.display_name,
        fm.avatar_color,
        COALESCE(SUM(CASE WHEN cc.name IN ('Haushalt','Besorgungen','Arbeit/Schule')
                          THEN ae.points ELSE 0.0 END), 0.0) AS duty_points,
        COALESCE(SUM(CASE WHEN cc.name = 'Hobby/Freizeit'
                          THEN ae.points ELSE 0.0 END), 0.0) AS leisure_points,
        COALESCE(SUM(ae.points), 0.0) AS total_points
    FROM public.family_members fm
    LEFT JOIN public.activity_entries ae
        ON ae.user_id = fm.id
        AND ae.family_id = fm.family_id
        AND ae.logged_at::date = CURRENT_DATE
    LEFT JOIN public.category_config cc ON cc.id = ae.category_id
    WHERE fm.family_id = (
        SELECT family_id FROM public.family_members WHERE id = (SELECT auth.uid())
    )
    GROUP BY fm.id, fm.display_name, fm.avatar_color;
END;
$$;
```

**Punkt-Berechnung bei INSERT:** Der Client berechnet `points = duration_minutes × point_weight` und speichert es explizit in `activity_entries.points`. Das ist sicher, weil `point_weight` aus `category_config` kommt, die der Client vorher geladen hat. In Phase 6 wird ein DB-Trigger diese Berechnung übernehmen — für Phase 4 ist die Client-Berechnung akzeptabel und bewusste Vereinfachung. [ASSUMED: Phase-6-Refactoring akzeptiert]

---

## State of the Art

| Alter Ansatz | Aktueller Ansatz | Geändert | Impact |
|--------------|-----------------|----------|--------|
| `Timer.publish()` + background processing | `timerStartedAt: Date?` persistent + Neuberechnung | iOS 16+ | Einfacher, kein Background-Task |
| `@Observable` macro | `ObservableObject + @Published` | — | `@Observable` erst iOS 17+; iOS 16 = ObservableObject |
| Custom Shapes für Ringe | `Circle().trim().stroke()` | SwiftUI 1.0 | Idiomatisch, gut dokumentiert, kein Custom-Shape nötig |
| Manuelles Score-Akkumulieren | DB Trigger + `weekly_summaries` | Phase 1 entschieden | Konsistenz, keine Race Conditions |

---

## Assumptions Log

| # | Claim | Abschnitt | Risiko wenn falsch |
|---|-------|-----------|-------------------|
| A1 | `point_weight = 1.0` für alle Kategorien in Phase 4 (Multiplikatoren erst Phase 6) | Pattern 3, Score-Berechnung | Geringe: UI-SPEC und SCORE-01 bestätigen Phase-4-Fix; SCORE-01 sagt "konfigurierbar" = Phase 6 |
| A2 | Supabase-Projekt-Timezone muss auf `Europe/Berlin` eingestellt sein für korrekte Wochenstart-Berechnung | Pitfall 1 | Mittel: Wenn UTC bleibt, können Montags-Übergänge nachts falsch sein — betrifft Wochenbeginn-Reset |
| A3 | Kinder-Profile aus Phase 3 haben `auth.users`-Einträge (d.h. echte `user_id`), nicht nur `family_members`-Zeilen | Pattern 4, LOG-04 | Hoch: Wenn Kinder keine `auth.users`-Einträge haben, funktioniert der RPC-Ansatz nicht; Phase 3 muss klären |
| A4 | `category_config`-Tabelle hat in Phase 4 bereits 4 Standardkategorien (aus Phase 1 oder Phase 3 Seeding) | Pattern 2 (Kategorie-IDs), LOG-06 | Mittel: Kein Seeding in Phase-1-Migration erkennbar — Phase 3 oder Phase 4 Wave 0 muss Seed-Migration liefern |

---

## Offene Fragen

1. **Timezone-Konfiguration des Supabase-Projekts**
   - Was wir wissen: PostgreSQL `date_trunc('week', ...)` nutzt Session-Timezone
   - Was unklar ist: Ist das Supabase-Projekt auf `Europe/Berlin` oder `UTC` eingestellt?
   - Empfehlung: In Phase 4 Wave 0 explizit prüfen; ggf. `AT TIME ZONE 'Europe/Berlin'` in alle RPC-Queries einfügen

2. **Kinder-Profile: `auth.users` oder nur `family_members`-Zeile?**
   - Was wir wissen: Phase 3 erstellt Kind-Profile; Architektur nicht festgelegt in Phase 3 Research
   - Was unklar ist: Hat ein Kind-Profil einen `auth.users`-Eintrag oder nur eine `family_members`-Zeile ohne Login?
   - Empfehlung: `create_activity_for_child`-RPC-Design hängt davon ab; mit Phase 3 Research abstimmen. Wenn Kinder keinen eigenen `auth.users`-Account haben, braucht die Tabelle eine `child_profile_id`-Spalte (kein FK auf `auth.users`)

3. **category_config Seeding**
   - Was wir wissen: Phase 1 erstellt die Tabelle, aber kein INSERT für Standardkategorien in der Migration
   - Was unklar ist: Wo werden Haushalt, Hobby/Freizeit, Besorgungen, Arbeit/Schule in die DB eingefügt?
   - Empfehlung: Phase 4 Wave 0 soll eine Seed-Migration oder einen `insert_default_categories(family_id uuid)` RPC liefern, der bei Family-Erstellung aufgerufen wird

---

## Umgebungsverfügbarkeit

| Dependency | Benötigt von | Verfügbar | Version | Fallback |
|------------|-------------|-----------|---------|---------|
| supabase-swift | ActivityService, alle DB-Calls | ✓ | 2.46.0 | — |
| Swift Charts | WeekSummaryView | ✓ | iOS 16+ (System) | — |
| Xcode 16 | Swift 6, iOS 16 Minimum | ✓ (laut CLAUDE.md) | 16 | — |
| Supabase Projekt (online) | RPC-Calls, Migrations | ✓ | Phase 1 eingerichtet | — |

Keine fehlenden Abhängigkeiten. Alle benötigten Tools sind verfügbar.

---

## Validation Architecture

### Test-Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (bereits konfiguriert, FamilyScoreTests-Target existiert) |
| Config-Datei | Xcode-Projekt (kein separates File) |
| Schnell-Run | `Cmd+U` in Xcode oder `xcodebuild test -scheme FamilyScore` |
| Vollständig | alle Unit-Tests im FamilyScoreTests-Target |

### Requirements → Test-Mapping

| Req ID | Verhalten | Test-Typ | Testbar ohne Device | Datei |
|--------|-----------|----------|-------------------|-------|
| LOG-01 | Timer startet und berechnet Minuten korrekt | Unit | ✓ | `ActivityServiceTests.swift` Wave 0 |
| LOG-01 | Timer überlebt App-Hintergrund (AppStorage) | Unit | ✓ | `ActivityServiceTests.swift` |
| LOG-02 | Retroaktiver Eintrag mit Kategorie + Dauer | Unit (Mock) | ✓ | `ActivityServiceTests.swift` |
| LOG-03 | Titel optional, korrekt mitgesendet | Unit (Mock) | ✓ | `ActivityServiceTests.swift` |
| LOG-04 | Kind-Eintrag via RPC erstellt | Unit (Mock) | ✓ | `ActivityServiceTests.swift` |
| LOG-05 | Eigener Eintrag gelöscht; Admin kann fremde löschen | Integration (Gerät) | ✗ | Gerät-Checkpoint |
| LOG-06 | 4 Kategorien vorhanden; Mapping Pflicht/Freizeit korrekt | Unit (Mock) | ✓ | `ActivityServiceTests.swift` |
| DASH-01 | Ring-Progress korrekt berechnet (duty/leisure/score) | Unit | ✓ | `ActivityServiceTests.swift` |
| DASH-01 | Überlauf > 100% — zweite Runde korrekt | Unit | ✓ | `RingProgressTests.swift` (neu) |
| DASH-02 | Familien-Scores geladen und korrekt zugeordnet | Unit (Mock) | ✓ | `ActivityServiceTests.swift` |
| DASH-03 | Wochenbilanz sortiert; Wochensieger korrekt | Unit | ✓ | `ActivityServiceTests.swift` |
| SCORE-01 | Punkte = Minuten × 1.0 (Phase 4 fix) | Unit | ✓ | `ActivityServiceTests.swift` |
| SCORE-02 | Kein Akkumulieren client-seitig; SUM aus Entries | Unit (Verify) | ✓ | `ActivityServiceTests.swift` |
| SCORE-03 | Tages- und Wochenscore korrekt aggregiert | Integration (Gerät) | ✗ | Gerät-Checkpoint |

### Sampling-Rate

- **Pro Task-Commit:** `Cmd+U` auf Unit-Tests (`ActivityServiceTests`, `RingProgressTests`)
- **Pro Wave-Merge:** Vollständige Test-Suite grün
- **Phase Gate:** Vollständige Test-Suite grün + Gerät-Checkpoint (echtes Gerät, echter JWT) vor `/gsd-verify-work`

### Wave 0 Gaps (müssen vor Implementation existieren)

- [ ] `FamilyScoreTests/ActivityServiceTests.swift` — 10+ Stubs (LOG-01 bis SCORE-03)
- [ ] `FamilyScoreTests/Mocks/MockActivityService.swift` — Protocol + Mock-Implementierung
- [ ] `FamilyScoreTests/RingProgressTests.swift` — Unit-Tests für Progress-Berechnung + Überlauf
- [ ] `ActivityServiceProtocol` — in `FamilyScore`-Target (wie `AuthServiceProtocol`)

---

## Security Domain

### ASVS-Kategorien

| ASVS Kategorie | Applicable | Standard-Kontrolle |
|----------------|-----------|-------------------|
| V2 Authentication | nein | Erledigt in Phase 2 |
| V3 Session Management | nein | Erledigt in Phase 2 |
| V4 Access Control | ja | RLS-Policies auf `activity_entries`; `SECURITY DEFINER` RPC für Kind-Zugriff |
| V5 Input Validation | ja | `duration_minutes > 0` in DB-Constraint; `max(240, min(5, input))` in Swift |
| V6 Cryptography | nein | Keine neue Kryptographie |

### Bekannte Threat-Patterns

| Pattern | STRIDE | Standardmitigation |
|---------|--------|-------------------|
| Eintrag für fremden User (nicht Kind) | Tampering | RLS `user_id = auth.uid()` + SECURITY DEFINER RPC prüft Eltern-Kind-Beziehung |
| Admin löscht Einträge anderer Familien | Tampering | `is_family_admin(family_id)` — nur eigene Familie |
| Client berechnet falsche Punktzahl | Tampering | DB-Constraint `points >= 0`; Phase 6 Trigger übernimmt Berechnung |
| Direktes INSERT mit falschem `family_id` | Tampering | RLS `is_family_member(family_id)` auf INSERT-Policy |
| Über-Overflow bei Zeitangabe | DoS | `duration_minutes CHECK > 0`; Swift-seitig auf 240 min cappen |

---

## Quellen

### Primary (HIGH confidence)
- supabase.com/docs/reference/swift/rpc — RPC-Aufruf-Syntax, `params:`, `.value`-Decoding
- supabase.com/docs/reference/swift/insert — Insert + `.select().single()` Pattern
- supabase.com/docs/reference/swift/delete — Delete + RLS-Verhalten
- supabase.com/docs/reference/swift/select — Select-Queries, Filter-Chaining
- postgresql.org/docs/current/functions-datetime.html — `date_trunc('week', ...)` ISO-Montag-Verhalten
- github.com/supabase/supabase-swift/releases — Version 2.46.0 bestätigt (29. April 2026)
- developer.apple.com/documentation/charts — Swift Charts iOS 16 Verfügbarkeit
- Apple Developer: `ScenePhase`, `presentationDetents` — iOS 16 native APIs

### Secondary (MEDIUM confidence)
- avanderlee.com/swift-charts/bar-chart-creation — Grouped BarMark mit `.position(by:)` und `.foregroundStyle(by:)`
- sarunw.com/posts/how-to-create-activity-ring-in-swiftui — Circle + trim + rotationEffect Pattern
- donnywals.com — presentationDetents iOS 16 Half-Sheet
- github.com/orgs/supabase/discussions/36295 — RLS-Problem bei INSERT mit anderem user_id bestätigt

### Tertiary (LOW confidence)
- medium.com/deuk — Timer-Artikel (Analyse ergab: kein echtes Background-Persistence, Timestamp-Ansatz ist korrekter)

---

## Metadata

**Konfidenz-Übersicht:**
- Ring-Visualisierung (Pattern 1): HIGH — offiziell dokumentiertes SwiftUI-Pattern, mehrfach verifiziert
- Supabase RPC (Pattern 2–4): HIGH — offizielle Docs, bestehender Schema-Kontext
- Timer-Persistenz (Pattern 6): MEDIUM — Grundprinzip (Timestamp) verifiziert; AppStorage-Details aus Training
- Swift Charts (Pattern 7): HIGH — offiziell iOS 16, Code-Beispiel aus verifizierter Quelle
- Kind-Eintrag RLS-Bypass (A3): MEDIUM — Annahme über Phase-3-Datenmodell noch nicht verifiziert

**Research-Datum:** 2026-05-16
**Gültig bis:** 2026-06-16 (supabase-swift minor updates möglich; Kern-Patterns stabil)
