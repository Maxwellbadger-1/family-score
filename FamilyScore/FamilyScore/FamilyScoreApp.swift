// FamilyScore/FamilyScoreApp.swift
// Target Membership: FamilyScore (App) ONLY
// Entry Point: @StateObject AuthService + RootView als Content + .environmentObject Injection

import SwiftUI

@main
struct FamilyScoreApp: App {

    // @StateObject: Lebenszyklus wird vom SwiftUI-Framework verwaltet (iOS 16 Muster)
    // NICHT @Observable — iOS 17+ und inkompatibel mit @StateObject-Injection
    @StateObject private var authService = AuthService()

    var body: some Scene {
        WindowGroup {
            RootView()
                // EnvironmentObject-Injection fuer alle Views im Hierarchy
                .environmentObject(authService)
                // startObserving() MUSS hier starten — nicht in einer untergeordneten View.
                // Pitfall 2: Wird .task erst in RootView oder LoginView aufgerufen,
                // kann INITIAL_SESSION bereits gesendet worden sein bevor die Beobachtung startet.
                // Source: RESEARCH.md Pitfall 2
                .task {
                    await authService.startObserving()
                }
                // Hintergrund: App wird schwarz wenn scenePhase = .background
                // Foreground: authStateChanges wird durch supabase-swift automatisch weitergefuehrt
                // Realtime reconnect (Phase 5) kommt spaeter; hier nur Auth-State beobachten
        }
    }
}

// MARK: - Phase 1 DEBUG-Verifikationsfunktionen
// Werden beibehalten fuer Rueckwaertskompatibilitaet mit Phase 1 SC-3/SC-4 Checks
// Koennen in Phase 6 (Cleanup) entfernt werden

#if DEBUG
func verifyAppGroup() {
    let suite = "group.com.familyscore"
    guard let defaults = UserDefaults(suiteName: suite) else {
        print("[DEBUG] App Group FAIL — UserDefaults(suiteName:) returned nil")
        return
    }
    let testKey = "phase1_verification"
    defaults.set(true, forKey: testKey)
    defaults.synchronize()
    let result = defaults.bool(forKey: testKey)
    print("[DEBUG] App Group Test: \(result ? "PASS" : "FAIL")")
}

func verifySupabaseConnection() async {
    do {
        try await supabase.from("families").select().execute()
        print("[DEBUG] Supabase Connection PASS")
    } catch {
        print("[DEBUG] Supabase Connection FAIL: \(error)")
    }
}
#endif
