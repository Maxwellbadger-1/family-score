// FamilyScore/Supabase.swift
// Target Membership: FamilyScore (App) ONLY — NIEMALS Widget Extension!
import Supabase

private func requireInfoPlistString(_ key: String) -> String {
    guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
          !value.isEmpty else {
        preconditionFailure(
            "'\(key)' fehlt oder ist leer in Info.plist. " +
            "Secrets.xcconfig mit echten Werten befuellen (siehe Secrets.xcconfig.template)."
        )
    }
    return value
}

let supabase = SupabaseClient(
    supabaseURL: URL(string: requireInfoPlistString("SUPABASE_URL"))!,
    supabaseKey: requireInfoPlistString("SUPABASE_KEY")
)
