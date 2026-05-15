// FamilyScore/Supabase.swift
// Target Membership: FamilyScore (App) ONLY — NIEMALS Widget Extension!
// Source: Supabase iOS Quickstart docs
import Supabase

let supabase = SupabaseClient(
    supabaseURL: URL(string: Bundle.main.object(
        forInfoDictionaryKey: "SUPABASE_URL") as! String)!,
    supabaseKey: Bundle.main.object(
        forInfoDictionaryKey: "SUPABASE_KEY") as! String
)
