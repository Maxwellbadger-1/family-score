// FamilyScore/Supabase.swift
// Target Membership: FamilyScore (App) ONLY — NIEMALS Widget Extension!
// KeychainLocalStorage: expliziter Service-Name verhindert Keychain-Prompt-Bug auf macOS/iOS
// Source: github.com/orgs/supabase/discussions/28132 (Pattern 5 aus RESEARCH.md)
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

let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://" + requireInfoPlistString("SUPABASE_URL"))!,
    supabaseKey: requireInfoPlistString("SUPABASE_KEY"),
    options: SupabaseClientOptions(
        auth: SupabaseClientOptions.AuthOptions(
            storage: KeychainLocalStorage(service: "com.familyscore")
            // Expliziter Service-Name verhindert Keychain-Prompt-Bug auf macOS/iOS
            // Source: github.com/orgs/supabase/discussions/28132
        )
    )
)
