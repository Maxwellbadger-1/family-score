// FamilyScore/Models/AppState.swift
// Target Membership: FamilyScore (App) ONLY
// Vollstaendige Implementierung: dieser Stub reicht fuer Wave 0 Kompilierung
// Wave 1 (Plan 02) erweitert diese Datei NICHT — sie ist bereits final

enum AppState: Equatable {
    case loading                        // App startet, INITIAL_SESSION ausstehend
    case unauthenticated                // Kein User, Login-Screen zeigen
    case authenticated(hasFamily: Bool) // User eingeloggt; family_id vorhanden oder nicht
}
