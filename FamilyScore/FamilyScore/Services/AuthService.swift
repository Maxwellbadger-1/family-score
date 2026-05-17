// FamilyScore/Services/AuthService.swift
// Target Membership: FamilyScore (App) ONLY
// iOS 16.0 Minimum: ObservableObject + @Published (NICHT @Observable — iOS 17+)
// Source: RESEARCH.md Pattern 2 (adaptiert fuer ObservableObject)
// Threat mitigations: T-2-02 (private(set)), T-2-03 (localizedError), T-2-05 (signedOut handler)

import Foundation
@preconcurrency import Supabase

@MainActor
final class AuthService: ObservableObject {

    @Published private(set) var appState: AppState = .loading
    @Published private(set) var currentUser: User? = nil

    // Fehler-State fuer UI-Feedback (settable aus View fuer Error-Banner-Dismiss)
    // T-2-07: authError enthaelt nur lokalisierte Meldungen — kein Stack-Trace, keine Server-Details
    @Published var authError: String? = nil

    // MARK: - Auth State Observation

    /// Muss beim App-Start gestartet werden (via .task{} in FamilyScoreApp).
    /// Das erste Event ist IMMER INITIAL_SESSION — mit oder ohne vorhandene Session.
    /// Anti-Pattern vermeiden: NIEMALS supabase.auth.currentSession synchron beim Start lesen.
    /// Pitfall 2: startObserving() FRUEH genug starten — in FamilyScoreApp.swift via .task{}
    /// WICHTIG: startObserving() wird NUR in FamilyScoreApp.swift gestartet (Plan 03 Task 2).
    /// RootView ruft startObserving() NICHT auf — sonst entstehen zwei simultane Schleifen.
    func startObserving() async {
        print("[Auth] startObserving() gestartet")
        for await (event, session) in await supabase.auth.authStateChanges {
            print("[Auth] Event: \(event), session: \(session != nil ? "vorhanden" : "nil")")
            switch event {
            case .initialSession, .signedIn:
                if let session {
                    currentUser = session.user
                    print("[Auth] Checking family membership fuer user: \(session.user.id)")
                    let hasFamily = await checkFamilyMembership(userId: session.user.id)
                    print("[Auth] hasFamily: \(hasFamily)")
                    appState = .authenticated(hasFamily: hasFamily)
                } else {
                    appState = .unauthenticated
                }
            case .signedOut:
                currentUser = nil
                appState = .unauthenticated
            case .tokenRefreshed:
                break
            default:
                break
            }
            print("[Auth] appState jetzt: \(appState)")
        }
        print("[Auth] startObserving() Stream beendet — unerwartet!")
    }

    // MARK: - E-Mail + Passwort

    func signUp(email: String, password: String, displayName: String) async throws {
        authError = nil
        // data["full_name"] wird von handle_new_user-Trigger in family_members.display_name geschrieben
        // Source: Phase 1 SQL-Migration — handle_new_user(): coalesce(new.raw_user_meta_data->>'full_name', 'New Member')
        try await supabase.auth.signUp(
            email: email,
            password: password,
            data: ["full_name": .string(displayName)]
        )
        // authStateChanges feuert SIGNED_IN → startObserving() aktualisiert appState
        // Kein manueller State-Update hier — Anti-Pattern vermeiden
    }

    func signIn(email: String, password: String) async throws {
        authError = nil
        try await supabase.auth.signIn(email: email, password: password)
        // authStateChanges feuert SIGNED_IN
    }

    func signOut() async throws {
        // .local loescht nur die lokale Session + Keychain ohne Netzwerkanfrage.
        // Funktioniert auch wenn das JWT abgelaufen ist (globaler Scope wuerde mit 401 fehlschlagen).
        try await supabase.auth.signOut(scope: .local)
        // authStateChanges feuert SIGNED_OUT → startObserving() setzt appState = .unauthenticated
        // Keychain wird von supabase-swift automatisch geleert
    }

    // MARK: - Family-Membership-Check

    /// Prueft ob der eingeloggte User eine family_id in family_members hat.
    /// Wird nach SIGNED_IN aufgerufen um authenticated(hasFamily:) zu bestimmen.
    /// RLS: family_members-Policy erlaubt id = auth.uid() → eigenes Profil lesbar.
    private func checkFamilyMembership(userId: UUID) async -> Bool {
        do {
            struct FamilyCheck: Decodable { let family_id: UUID? }
            let result: [FamilyCheck] = try await supabase
                .from("family_members")
                .select("family_id")
                .eq("id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value
            return result.first?.family_id != nil
        } catch {
            print("[Auth] checkFamilyMembership Fehler: \(error)")
            return false
        }
    }

    // MARK: - Error Lokalisierung

    /// Supabase Auth-Fehler in nutzerfreundliche deutsche Meldungen uebersetzen.
    /// T-2-07: Nur lokalisierte Strings — kein roher Server-Error-Text wird an UI weitergegeben.
    func localizedError(from error: Error) -> String {
        let msg = error.localizedDescription.lowercased()
        if msg.contains("invalid login") || msg.contains("invalid credentials") || msg.contains("email not confirmed") {
            return "E-Mail-Adresse oder Passwort falsch."
        } else if msg.contains("network") || msg.contains("connection") || msg.contains("offline") {
            return "Keine Internetverbindung. Bitte pruefen."
        } else if msg.contains("already registered") || msg.contains("already exists") || msg.contains("user already") {
            return "Diese E-Mail-Adresse ist bereits registriert."
        } else if msg.contains("password") && msg.contains("short") {
            return "Passwort muss mindestens 6 Zeichen lang sein."
        }
        return "Ein Fehler ist aufgetreten. Bitte erneut versuchen."
    }

    // MARK: - Family Status Refresh (Phase 3)

    /// Wird von Views nach createFamily() und joinFamily() aufgerufen.
    /// FamilyService gibt die neue family_id zurueck; die View ruft danach refreshFamilyStatus()
    /// auf AuthService auf. So bleibt die Dependency-Richtung sauber:
    /// Views → Services (nie Services → Services direkt).
    ///
    /// Pitfall 3 (RESEARCH.md): authStateChanges feuert kein neues Event wenn
    /// family_members.family_id sich aendert — daher manueller refresh noetig.
    func refreshFamilyStatus() async {
        guard let userId = currentUser?.id else { return }
        let hasFamily = await checkFamilyMembership(userId: userId)
        appState = .authenticated(hasFamily: hasFamily)
    }
}
