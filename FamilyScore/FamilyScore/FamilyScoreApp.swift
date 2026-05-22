// FamilyScore/FamilyScoreApp.swift
// Target Membership: FamilyScore (App) ONLY
// Entry Point: @StateObject AuthService + RootView als Content + .environmentObject Injection

import SwiftUI
import Supabase

@main
struct FamilyScoreApp: App {

    // @StateObject: Lebenszyklus wird vom SwiftUI-Framework verwaltet (iOS 16 Muster)
    // NICHT @Observable — iOS 17+ und inkompatibel mit @StateObject-Injection
    @StateObject private var authService = AuthService()
    @StateObject private var familyService = FamilyService()
    @StateObject private var activityService = ActivityService()

    var body: some Scene {
        WindowGroup {
            RootView()
                // EnvironmentObject-Injection fuer alle Views im Hierarchy
                .environmentObject(authService)
                .environmentObject(familyService)
                .environmentObject(activityService)
                // startObserving() MUSS hier starten — nicht in einer untergeordneten View.
                // Pitfall 2: Wird .task erst in RootView oder LoginView aufgerufen,
                // kann INITIAL_SESSION bereits gesendet worden sein bevor die Beobachtung startet.
                // Source: RESEARCH.md Pitfall 2
                .task {
                    guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
                        print("[App] XCTest-Umgebung erkannt — startObserving() uebersprungen")
                        return
                    }
                    print("[App] App gestartet, startObserving() wird aufgerufen")
                    await authService.startObserving()
                }
                // Hintergrund: App wird schwarz wenn scenePhase = .background
                // Foreground: authStateChanges wird durch supabase-swift automatisch weitergefuehrt
                // Realtime reconnect (Phase 5) kommt spaeter; hier nur Auth-State beobachten
                // Rule 2: currentFamilyId in ActivityService synken wenn Familie geladen wird
                .onChange(of: familyService.currentFamily?.id) { newFamilyId in
                    activityService.currentFamilyId = newFamilyId
                }
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
