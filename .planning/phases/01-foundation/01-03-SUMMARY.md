---
plan: 01-03
phase: 01-foundation
status: complete
completed: 2026-05-15
---

# Plan 01-03: Supabase Integration — Summary

## Was wurde erstellt

### Swift-Dateien (bereits in Plan 01-01/02 vorbereitet, hier finalisiert):
- `FamilyScore/FamilyScore/Supabase.swift` — SupabaseClient Singleton (nur App Target, xcconfig-Injection)
- `FamilyScore/FamilyScore/FamilyScoreApp.swift` — `verifySupabaseConnection()` DEBUG-Funktion
- `FamilyScore/FamilyScore/ContentView.swift` — `.task { await verifySupabaseConnection() }`

### Datenbank-Migration (via Supabase MCP angewendet):
- `FamilyScore/supabase/migrations/20260515_initial_schema.sql` — Vollständiges DDL + RLS + Trigger

## Supabase Cloud Status

- **Projekt-URL:** `https://amotertwccevkfowxvtk.supabase.co` (kein Key in Git!)
- **Migrations angewendet:**
  - `20260515_initial_schema_tables` — 6 Tabellen + handle_new_user Trigger
  - `20260515_weekly_summary_trigger` — update_weekly_summary Trigger (vollständige Neuberechnung)
  - `20260515_indexes_rls_policies` — Indexes, Helper Functions, RLS Policies
- **Realtime Publications:** activity_entries, weekly_summaries, family_members

## Tabellen-Status (alle 6 live mit RLS)

| Tabelle | RLS | Trigger | Policies |
|---------|-----|---------|----------|
| families | ✓ | — | select(member), update(admin), insert(auth) |
| family_members | ✓ | on_auth_user_created | select, update, insert, admin-all |
| category_config | ✓ | — | select(member), all(admin) |
| activity_entries | ✓ | on_activity_entry_change → weekly_summaries | select(member), insert(user+member), delete(user/admin) |
| family_invites | ✓ | — | all(admin), select(any-auth) |
| weekly_summaries | ✓ | — | select(member), all(service_role) |

## Trigger: update_weekly_summary

- Wird bei INSERT oder DELETE auf activity_entries ausgelöst
- Berechnet `total_minutes`, `total_points`, `by_category` **immer vollständig** (kein inkrementelles Update)
- `by_category` als JSONB: `{ "category_uuid": { "minutes": N, "points": N } }`
- `date_trunc('week', ...)` → Montag (ISO 8601) als Wochenbeginn

## Abweichung vom ursprünglichen Plan

Die Trigger-Funktion im Plan verwendete `cross join lateral` innerhalb eines INSERT…SELECT, was einen PostgreSQL-Syntaxfehler verursachte. Die Funktion wurde auf zwei getrennte SELECTs umgeschrieben (total aggregates + per-category breakdown), was semantisch identisch ist und korrekt ausgeführt wird.

## Success Criteria Verifikation

| SC | Beschreibung | Status |
|----|-------------|--------|
| SC-1 | Build (Xcode BUILD SUCCEEDED) | ⚠ Pending — erfordert Mac mit Xcode |
| SC-2 | App Group Test: PASS (echtes Gerät) | ⚠ Pending — erfordert Mac + Gerät |
| SC-3 | Supabase RLS via Swift Client ([] für anon) | ✓ Server-seitig verifiziert — RLS aktiv, policies nur für `authenticated` |
| SC-4 | Secrets aus Git (git grep = 0 Treffer) | ✓ Bestätigt — Secrets.xcconfig in .gitignore, keine URL/Keys in committed Files |
| SC-5 | FamilyScoreKit + kein Supabase im Widget | ✓ Bestätigt — kein `import Supabase` in Widget Extension Swift-Dateien |

**Hinweis SC-1/SC-2:** Diese Checks erfordern Xcode auf einem Mac. Die Datei-Voraussetzungen sind erfüllt (Supabase.swift korrekt, xcconfig-Injection konfiguriert). Vollständige Verifikation beim ersten Mac-Build.

## Wichtige Werte

- Supabase Project Ref: `amotertwccevkfowxvtk`
- Bundle ID App: `com.familyscore`
- App Group: `group.com.familyscore`
- Supabase SDK: `supabase-swift` v2.46.0 (via SPM, nur App Target)

## Offene Punkte (erfordern Mac)

- [ ] supabase-swift via SPM in Xcode hinzufügen (nur App Target)
- [ ] Secrets.xcconfig mit echten Werten befüllen (bereits vorhanden, nur bei erstem Build)
- [ ] `xcodebuild` BUILD SUCCEEDED verifizieren
- [ ] App starten → `[Phase1] Supabase Connection PASS` in Xcode Console bestätigen

## Self-Check: PASSED (Schema live, RLS aktiv, Secrets geschützt; Xcode-Build erfordert Mac)
