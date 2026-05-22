// FamilyScore/Services/ActivityService.swift
// Target Membership: FamilyScore (App) ONLY
// Supabase SDK NUR hier — nicht in FamilyScoreKit, nicht in Widget Extension (CLAUDE.md)
// iOS 16.0 Minimum: ObservableObject + @Published (NICHT @Observable — iOS 17+)
// Threat mitigations: T-4-01 (create_activity_for_child RPC), T-4-04 (currentFamilyId aus Session),
//                    T-4-05 (duration_minutes cap max 240)

import Foundation
import SwiftUI
@preconcurrency import Supabase

@MainActor
final class ActivityService: ObservableObject, ActivityServiceProtocol {

    // MARK: - Published State (read-only — private(set) per PATTERNS.md)

    @Published private(set) var todayEntries: [ActivityEntry] = []
    @Published private(set) var categories: [CategoryConfig] = []
    @Published private(set) var dayScore: DayScore? = nil
    @Published private(set) var weeklyScores: [WeeklySummary] = []
    @Published private(set) var familyDayScores: [MemberDayScore] = []
    @Published private(set) var dutyProgress: Double = 0.0
    @Published private(set) var leisureProgress: Double = 0.0
    @Published private(set) var scoreProgress: Double = 0.0
    @Published private(set) var totalScore: Int = 0
    @Published private(set) var allTimeStats: AllTimeStats? = nil  // DASH-04

    // activityError ohne private(set) — UI darf nach Anzeige nil setzen
    @Published var activityError: String? = nil

    // MARK: - Timer-Persistenz (Pitfall 2: kein UUID direkt in @AppStorage — als String)

    @AppStorage("timerStartedAt") private var timerStartedAtInterval: Double = 0
    @AppStorage("timerCategoryId") private var timerCategoryIdString: String = ""

    var timerIsRunning: Bool { timerStartedAtInterval > 0 }

    private var timerStartedAt: Date? {
        timerStartedAtInterval > 0 ? Date(timeIntervalSince1970: timerStartedAtInterval) : nil
    }

    var elapsedSeconds: TimeInterval {
        guard let start = timerStartedAt else { return 0 }
        return Date.now.timeIntervalSince(start)
    }

    // MARK: - Family/User IDs
    // currentFamilyId wird von FamilyScoreApp.swift nach dem Family-Load gesetzt (T-4-04)
    var currentFamilyId: UUID?

    private var currentUserId: UUID? {
        supabase.auth.currentUser?.id
    }

    // MARK: - fetchTodayData() — family-weiter Familien-Feed (DASH-05)
    // KEIN user_id-Filter — alle Familienmitglieder-Eintraege landen in todayEntries

    func fetchTodayData() async throws {
        guard let familyId = currentFamilyId else { return }

        // 1. Kategorien laden (gefiltert nach family_id, nur aktivierte)
        let fetchedCategories: [CategoryConfig] = try await supabase
            .from("category_config")
            .select("*")
            .eq("family_id", value: familyId.uuidString)
            .eq("is_enabled", value: true)
            .order("sort_order")
            .execute()
            .value
        categories = fetchedCategories

        // 2. Tageseintraege laden — family-weiter Query ohne user_id-Filter (DASH-05)
        // date(logged_at) = CURRENT_DATE via PostgreSQL-Vergleich
        let today = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))
        let tomorrow = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: Date())!))
        let fetchedEntries: [ActivityEntry] = try await supabase
            .from("activity_entries")
            .select("*")
            .eq("family_id", value: familyId.uuidString)
            .gte("logged_at", value: today)
            .lt("logged_at", value: tomorrow)
            .order("logged_at", ascending: false)
            .execute()
            .value
        todayEntries = fetchedEntries

        // 3. Tagesscore via RPC laden (autoritativer Wert vom Server — Pitfall 6)
        let scores: [DayScore] = try await supabase
            .rpc("get_today_score")
            .execute()
            .value
        dayScore = scores.first

        // 4. Ring-Progress aus lokalen Eintraegen berechnen
        refreshLocalRingProgress()
    }

    // MARK: - fetchFamilyData() — Familien-Tagescores (DASH-02)

    func fetchFamilyData() async throws {
        let scores: [MemberDayScore] = try await supabase
            .rpc("get_family_today_scores")
            .execute()
            .value
        familyDayScores = scores
    }

    // MARK: - fetchWeeklyData() — Wochenbilanz aus weekly_summaries (DASH-03)

    func fetchWeeklyData() async throws {
        guard let familyId = currentFamilyId else { return }
        let summaries: [WeeklySummary] = try await supabase
            .from("weekly_summaries")
            .select("*")
            .eq("family_id", value: familyId.uuidString)
            .order("week_start", ascending: false)
            .limit(10)
            .execute()
            .value
        weeklyScores = summaries
    }

    // MARK: - fetchAllTimeStats() — Gesamt-Statistiken seit App-Start (DASH-04)
    // SELECT SUM ohne Datumsfilter — nur family_id einschraenken

    func fetchAllTimeStats() async throws {
        guard let familyId = currentFamilyId,
              let userId = currentUserId else { return }

        struct StatsRow: Decodable {
            let totalDurationMinutes: Int?
            let totalPoints: Double?
            enum CodingKeys: String, CodingKey {
                case totalDurationMinutes = "total_duration_minutes"
                case totalPoints = "total_points"
            }
        }

        // Supabase PostgREST aggregation via select mit Postgres-Funktionen
        // Alternativ: direkte sum-Berechnung aus geladenen Daten (Phase 4: einfache Loesung)
        let rows: [ActivityEntry] = try await supabase
            .from("activity_entries")
            .select("*")
            .eq("family_id", value: familyId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        let totalMinutes = rows.reduce(0) { $0 + $1.durationMinutes }
        let totalPoints = rows.reduce(0.0) { $0 + $1.points }
        allTimeStats = AllTimeStats(
            totalHours: Double(totalMinutes) / 60.0,
            totalPoints: totalPoints
        )
    }

    // MARK: - logActivity() — Optimistic Insert + Rollback (RESEARCH.md Pattern 3 + 10)

    func logActivity(categoryId: UUID, durationMinutes: Int, title: String?) async throws {
        guard let familyId = currentFamilyId,
              let userId = currentUserId else { throw ActivityError.notAuthenticated }

        // T-4-05 DoS-Schutz: duration_minutes auf 1–240 cappend
        let capped = max(1, min(240, durationMinutes))
        let weight = categories.first(where: { $0.id == categoryId })?.pointWeight ?? 1.0
        let pts = Double(capped) * weight

        // Optimistischer Eintrag (temp UUID)
        let tempId = UUID()
        let optimistic = ActivityEntry(
            id: tempId,
            familyId: familyId,
            userId: userId,
            categoryId: categoryId,
            durationMinutes: capped,
            points: pts,
            title: title,
            loggedAt: Date()
        )
        let backup = todayEntries
        todayEntries.insert(optimistic, at: 0)
        refreshLocalRingProgress()

        do {
            let entry = NewActivityEntry(
                familyId: familyId,
                userId: userId,
                categoryId: categoryId,
                durationMinutes: capped,
                points: pts,
                title: title
            )
            let saved: ActivityEntry = try await supabase
                .from("activity_entries")
                .insert(entry)
                .select()
                .single()
                .execute()
                .value

            // Optimistischen Eintrag durch echten ersetzen
            todayEntries.removeAll { $0.id == tempId }
            todayEntries.insert(saved, at: 0)

            // Authoritativen Wert vom Server laden (Pitfall 6)
            let scores: [DayScore] = try await supabase
                .rpc("get_today_score")
                .execute()
                .value
            dayScore = scores.first
            refreshLocalRingProgress()

        } catch {
            // Rollback bei Fehler
            todayEntries = backup
            refreshLocalRingProgress()
            activityError = localizedError(from: error)
            throw error
        }
    }

    // MARK: - logActivityForChild() — SECURITY DEFINER RPC (T-4-01 mitigiert)
    // Kein direktes INSERT mit fremder user_id — ausschliesslich via RPC

    func logActivityForChild(childUserId: UUID, categoryId: UUID, durationMinutes: Int, title: String?) async throws {
        // T-4-05 DoS-Schutz
        let capped = max(1, min(240, durationMinutes))
        let weight = categories.first(where: { $0.id == categoryId })?.pointWeight ?? 1.0

        struct ChildParams: Encodable {
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

        let params = ChildParams(
            pChildUserId: childUserId,
            pCategoryId: categoryId,
            pDurationMin: capped,
            pPoints: Double(capped) * weight,
            pTitle: title
        )

        do {
            let _: ActivityEntry = try await supabase
                .rpc("create_activity_for_child", params: params)
                .execute()
                .value
            // Nach Erfolg: Familien-Feed neu laden (fetchTodayData ladet alle Familienmitglieder)
            try await fetchTodayData()
        } catch {
            activityError = localizedError(from: error)
            throw error
        }
    }

    // MARK: - deleteActivity() — Optimistic Delete + Rollback (RESEARCH.md Pattern 5)
    // RLS-Policy aus Phase 1 entscheidet — kein Swift-seitiger Role-Check (T-4-02)

    func deleteActivity(id: UUID) async throws {
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
            activityError = localizedError(from: error)
            throw error
        }
    }

    // MARK: - Timer (RESEARCH.md Pattern 6)

    func startTimer(categoryId: UUID) {
        timerStartedAtInterval = Date.now.timeIntervalSince1970
        timerCategoryIdString = categoryId.uuidString
    }

    func stopTimer(title: String?) async throws {
        guard let start = timerStartedAt,
              let categoryId = UUID(uuidString: timerCategoryIdString) else { return }
        // T-4-05: Timer-Dauer ebenfalls auf 1–240 cappen
        let minutes = max(1, min(240, Int(Date.now.timeIntervalSince(start) / 60)))
        // Timer-State zuruecksetzen BEVOR logActivity (UI reagiert sofort)
        timerStartedAtInterval = 0
        timerCategoryIdString = ""
        try await logActivity(categoryId: categoryId, durationMinutes: minutes, title: title)
    }

    // MARK: - Ring-Progress Berechnung (NIEMALS akkumulieren — CLAUDE.md Architektur-Regel)
    // 60 pts = Ring full (UI-SPEC Score Contract)

    func refreshLocalRingProgress() {
        let dutyIds = Set(categories.filter { $0.ringType == .duty }.map(\.id))
        let leisureIds = Set(categories.filter { $0.ringType == .leisure }.map(\.id))

        let dutyPts = todayEntries
            .filter { dutyIds.contains($0.categoryId) }
            .reduce(0.0) { $0 + $1.points }
        let leisurePts = todayEntries
            .filter { leisureIds.contains($0.categoryId) }
            .reduce(0.0) { $0 + $1.points }
        let totalPts = todayEntries.reduce(0.0) { $0 + $1.points }

        // 60 pts = Ring full (UI-SPEC)
        dutyProgress = dutyPts / 60.0
        leisureProgress = leisurePts / 60.0
        scoreProgress = totalPts / 60.0
        totalScore = Int(totalPts)
    }

    // MARK: - Error Lokalisierung
    // Exakt selbe Struktur wie AuthService.localizedError (PATTERNS.md)
    // T-2-07-Analogon: Nur nutzerfreundliche Strings, kein roher Server-Error-Text

    func localizedError(from error: Error) -> String {
        let msg = error.localizedDescription.lowercased()
        if msg.contains("network") || msg.contains("connection") || msg.contains("offline") {
            return "Eintrag konnte nicht gespeichert werden — prüfe deine Internetverbindung und versuche es erneut."
        } else if msg.contains("not authenticated") || msg.contains("unauthorized") || msg.contains("jwt") {
            return "Du bist nicht angemeldet. Bitte melde dich erneut an."
        } else if msg.contains("permission") || msg.contains("policy") || msg.contains("berechtigt") {
            return "Keine Berechtigung für diese Aktion."
        } else if msg.contains("constraint") || msg.contains("violates") {
            return "Ungültige Eingabe. Bitte prüfe deine Daten."
        }
        return "Ein Fehler ist aufgetreten. Bitte erneut versuchen."
    }
}

// MARK: - ActivityError

enum ActivityError: Error {
    case notAuthenticated
}
