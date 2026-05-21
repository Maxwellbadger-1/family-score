// FamilyScore/Supabase.swift
// Target Membership: FamilyScore (App) ONLY — NIEMALS Widget Extension!
// UserDefaultsLocalStorage: KeychainLocalStorage schlägt in virtuellen Umgebungen
// (Appetize.io, bestimmte CI-Simulatoren) lautlos fehl → Session-Reads geben nil
// zurück → supabase fällt auf Anon-Key zurück → alle RLS-Calls fehlschlagen.
// UserDefaults ist in allen Umgebungen zuverlässig und für Auth-Tokens (kurzlebig,
// kein langfristiger Wert ohne Refresh) ausreichend.
import Foundation
import Supabase

private func requireInfoPlistString(_ key: String) -> String {
    guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
          !value.isEmpty else {
        print("[Supabase] FATAL: '\(key)' fehlt oder ist leer in Info.plist")
        print("[Supabase] Verfuegbare Info.plist Keys: \(Bundle.main.infoDictionary?.keys.sorted().joined(separator: ", ") ?? "keine")")
        preconditionFailure(
            "'\(key)' fehlt oder ist leer in Info.plist. " +
            "Secrets.xcconfig mit echten Werten befuellen (siehe Secrets.xcconfig.template)."
        )
    }
    if key == "SUPABASE_URL" {
        print("[Supabase] URL: \(value)")
    } else {
        print("[Supabase] '\(key)': \(value.count) Zeichen geladen")
    }
    return value
}

// UserDefaults-basierter Auth-Storage — funktioniert in Appetize.io, Simulator, echtem Gerät.
// @unchecked Sendable ist sicher: UserDefaults.standard ist thread-safe (Apple-Garantie).
private final class UserDefaultsLocalStorage: AuthLocalStorage, @unchecked Sendable {
    private let prefix = "sb.auth."
    private enum E: Error { case notFound }

    func store(key: String, value: Data) throws {
        UserDefaults.standard.set(value, forKey: prefix + key)
        print("[Supabase] Session gespeichert (UserDefaults): \(key)")
    }

    func retrieve(key: String) throws -> Data {
        guard let data = UserDefaults.standard.data(forKey: prefix + key) else {
            throw E.notFound
        }
        print("[Supabase] Session geladen (UserDefaults): \(key)")
        return data
    }

    func remove(key: String) throws {
        UserDefaults.standard.removeObject(forKey: prefix + key)
        print("[Supabase] Session entfernt (UserDefaults): \(key)")
    }
}

let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://" + requireInfoPlistString("SUPABASE_URL"))!,
    supabaseKey: requireInfoPlistString("SUPABASE_KEY"),
    options: SupabaseClientOptions(
        auth: SupabaseClientOptions.AuthOptions(
            storage: UserDefaultsLocalStorage(),
            // emitLocalSessionAsInitialSession: Gespeicherte Session sofort emitten,
            // unabhaengig von Gueltigkeit. Verhindert Race-Condition bei gescheitertem
            // Initial-Refresh (SDK-Bug, behoben in naechstem Major-Release).
            // Source: supabase-swift PR #822
            emitLocalSessionAsInitialSession: true
        )
    )
)
