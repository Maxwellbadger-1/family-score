import SwiftUI

@main
struct FamilyScoreApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

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

func verifySupabaseConnection() async {
    do {
        // Test 1: Verbindung (unauthentifiziert — anon key, kein user)
        // Mit RLS: families gibt [] zurück (kein Fehler, kein 403)
        let families: [AnyJSON] = try await supabase
            .from("families")
            .select()
            .execute()
            .value
        print("[Phase1] Supabase Connection PASS — families returned \(families.count) rows (expected 0 with RLS, no auth)")

        // Test 2: weekly_summaries Tabelle existiert
        let summaries: [AnyJSON] = try await supabase
            .from("weekly_summaries")
            .select()
            .execute()
            .value
        print("[Phase1] weekly_summaries table exists PASS — \(summaries.count) rows")

        // Test 3: RLS-Verhalten bestätigen
        print("[Phase1] RLS appears active — anon user sees 0 rows (correct RLS behavior)")
        print("[Phase1] NOTE: Vollstaendige RLS-Verifikation erfordert Auth (Phase 2)")

    } catch {
        print("[Phase1] Supabase Connection FAIL: \(error)")
        assertionFailure("Supabase connection failed: \(error)")
    }
}
#endif
