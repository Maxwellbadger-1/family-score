---
phase: 01-foundation
reviewed: 2026-05-15T21:03:29Z
depth: standard
files_reviewed: 14
files_reviewed_list:
  - .gitignore
  - FamilyScore/Config/Config.xcconfig
  - FamilyScore/Config/Secrets.xcconfig.template
  - FamilyScore/FamilyScore/ContentView.swift
  - FamilyScore/FamilyScore/FamilyScoreApp.swift
  - FamilyScore/FamilyScore/Resources/FamilyScore.entitlements
  - FamilyScore/FamilyScore/Resources/Info.plist
  - FamilyScore/FamilyScore/Supabase.swift
  - FamilyScore/FamilyScoreKit/Package.swift
  - FamilyScore/FamilyScoreKit/Sources/FamilyScoreKit/WidgetData.swift
  - FamilyScore/FamilyScoreWidgetExtension/FamilyScoreWidget.swift
  - FamilyScore/FamilyScoreWidgetExtension/FamilyScoreWidgetBundle.swift
  - FamilyScore/FamilyScoreWidgetExtension/FamilyScoreWidgetExtension.entitlements
  - FamilyScore/supabase/migrations/20260515_initial_schema.sql
findings:
  critical: 2
  warning: 3
  info: 2
  total: 7
status: issues_found
---

# Phase 01: Code Review Report

**Reviewed:** 2026-05-15T21:03:29Z
**Depth:** standard
**Files Reviewed:** 14
**Status:** issues_found

## Summary

14 Dateien der Phase-1-Foundation wurden reviewed: Swift-App-Struktur (Xcode-Targets, entitlements, xcconfig), das FamilyScoreKit Swift Package sowie die Supabase-Migrationsdatei mit Schema, Triggern und RLS-Policies.

Die Projektstruktur folgt den in CLAUDE.md definierten Architekturregeln korrekt — Supabase SDK ist nur im App-Target, das App Group Identifier ist konsistent, `WidgetData` implementiert `Sendable`, und Secrets sind via xcconfig und .gitignore sauber getrennt.

Es gibt jedoch zwei kritische Probleme: ein Datenleck in den RLS-Policies fuer Einladungs-Tokens, und forced-unwrap-Crashes beim App-Start wenn die Supabase-Konfiguration fehlt. Ausserdem fehlt im Trigger die Behandlung von UPDATE-Operationen auf `activity_entries`, was zu Dateninkonsistenz in `weekly_summaries` fuehren kann.

## Critical Issues

### CR-01: RLS-Policy gibt alle Einladungs-Tokens an jeden authentifizierten User preis

**File:** `FamilyScore/supabase/migrations/20260515_initial_schema.sql:329-331`
**Issue:** Die SELECT-Policy auf `family_invites` erlaubt mit `using (true)` jedem authentifizierten User, saemtliche Einladungs-Datensaetze aller Familien zu lesen. Das schliesst die `token`-Spalte ein — 12-Byte-Base64-Tokens, die als Zugangscode fuer Familiengruppen fungieren. Ein angemeldeter User (z.B. ein boeswilliger Akteur aus einer anderen Familie) koennte alle aktiven Tokens abfragen und diese fuer unbefugten Familienbeitritt verwenden (Token-Replay-Angriff).

```sql
-- AKTUELL (unsicher):
create policy "Jeder authentifizierte User kann Einladung per Token lesen"
  on public.family_invites for select to authenticated
  using (true);   -- <-- gibt alle Tokens aller Familien preis

-- FIX OPTION A: User sieht nur Einladungen seiner eigenen Familie (als Admin)
-- oder Einladungen, die speziell fuer ihn bestimmt sind
create policy "User liest eigene oder admin-verwaltete Einladungen"
  on public.family_invites for select to authenticated
  using (
    public.is_family_admin(family_id)
    or used_by = (select auth.uid())
  );

-- FIX OPTION B: Token-Lookup via separater RPC (kein direkter Tabellen-SELECT)
-- Die App ruft eine SECURITY DEFINER-Funktion auf:
create or replace function public.lookup_invite(p_token text)
returns table(family_id uuid, role text, expires_at timestamptz)
language sql
security definer
set search_path = ''
as $$
  select family_id, role, expires_at
  from public.family_invites
  where token = p_token
    and used_by is null
    and expires_at > now();
$$;
-- Dann: RLS-SELECT-Policy entfernen, Tabelle nur ueber RPC zugaenglich machen
```

Option B ist vorzuziehen, da sie das Token niemals in einem User-sichtbaren Datensatz zurueckgibt.

---

### CR-02: Forced-Unwrap in Supabase.swift crasht bei fehlendem/leerem Config-Wert

**File:** `FamilyScore/FamilyScore/Supabase.swift:8-11`
**Issue:** Zwei `!`-forced-unwraps (ein `as! String` und ein `URL(...)!`) werden beim App-Start als global initialisierter Singleton ausgefuehrt. Wenn `SUPABASE_URL` oder `SUPABASE_KEY` im Info.plist fehlen oder leer sind (z.B. bei einem neuen Entwickler, der `Secrets.xcconfig` noch nicht angelegt hat), gibt es einen fatalen `EXC_BAD_INSTRUCTION`-Crash ohne verstaendliche Fehlermeldung. Der Crash tritt vor jedem UI-Code auf, wodurch er schwer zu diagnostizieren ist.

```swift
// AKTUELL (unsicher):
let supabase = SupabaseClient(
    supabaseURL: URL(string: Bundle.main.object(
        forInfoDictionaryKey: "SUPABASE_URL") as! String)!,
    supabaseKey: Bundle.main.object(
        forInfoDictionaryKey: "SUPABASE_KEY") as! String
)

// FIX: Guard mit verstaendlichem preconditionFailure
private func loadRequiredInfoPlistString(_ key: String) -> String {
    guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
          !value.isEmpty,
          !value.hasPrefix("REPLACE_WITH") else {
        preconditionFailure(
            "[FamilyScore] '\(key)' fehlt oder ist nicht konfiguriert. " +
            "Bitte Secrets.xcconfig anlegen (siehe Secrets.xcconfig.template)."
        )
    }
    return value
}

let supabase: SupabaseClient = {
    let urlString = loadRequiredInfoPlistString("SUPABASE_URL")
    let key = loadRequiredInfoPlistString("SUPABASE_KEY")
    guard let url = URL(string: urlString) else {
        preconditionFailure("[FamilyScore] SUPABASE_URL ist keine gueltige URL: \(urlString)")
    }
    return SupabaseClient(supabaseURL: url, supabaseKey: key)
}()
```

Der zusaetzliche `hasPrefix("REPLACE_WITH")`-Check verhindert ausserdem, dass eine unkonfigurierte Template-URL den Crash verschleiert.

---

## Warnings

### WR-01: Trigger auf activity_entries behandelt kein UPDATE — weekly_summaries wird bei Aenderungen nicht neu berechnet

**File:** `FamilyScore/supabase/migrations/20260515_initial_schema.sql:187-189`
**Issue:** Der Trigger `on_activity_entry_change` wird nur bei `INSERT` und `DELETE` ausgefuehrt, nicht bei `UPDATE`. Wenn ein bestehender `activity_entries`-Datensatz nachtraeglich geaendert wird (z.B. `duration_minutes` oder `points` korrigiert), bleiben `weekly_summaries.total_minutes` und `weekly_summaries.total_points` auf dem alten Stand — eine stille Dateninkonsistenz.

```sql
-- AKTUELL (unvollstaendig):
create trigger on_activity_entry_change
  after insert or delete on public.activity_entries
  for each row execute procedure public.update_weekly_summary();

-- FIX: UPDATE ebenfalls abdecken
create trigger on_activity_entry_change
  after insert or update or delete on public.activity_entries
  for each row execute procedure public.update_weekly_summary();
```

Da `activity_entries` konzeptionell append-only ist und keine UPDATE-Policy in RLS definiert ist, tritt das Problem in der Praxis vorerst nicht auf. Die fehlende Absicherung auf DB-Ebene ist jedoch ein latentes Risiko, falls spaeter eine Admin-Update-Policy hinzugefuegt wird.

---

### WR-02: App Group Identifier im Widget als String-Literal statt ueber appGroupIdentifier-Konstante

**File:** `FamilyScore/FamilyScoreWidgetExtension/FamilyScoreWidget.swift:17`
**Issue:** Der App Group Identifier `"group.com.familyscore"` wird als hart kodiertes String-Literal verwendet, obwohl `FamilyScoreKit` bereits die Konstante `appGroupIdentifier` als Single Source of Truth definiert. Bei einer zukuenftigen Umbenennung der App Group muss diese Stelle manuell synchronisiert werden — ein typischer Copy-Paste-Fehler.

```swift
// AKTUELL:
let debugDefaults = UserDefaults(suiteName: "group.com.familyscore")

// FIX: Konstante aus FamilyScoreKit verwenden
import FamilyScoreKit
let debugDefaults = UserDefaults(suiteName: appGroupIdentifier)
```

Das Widget-Target muss `FamilyScoreKit` bereits als Dependency haben (es wird `WidgetData` benoetigt), daher ist kein zusaetzlicher Import-Aufwand noetig — `appGroupIdentifier` ist bereits verfuegbar.

---

### WR-03: RLS-Policy auf family_members — "Admin verwaltet Familienmitglieder" kollidiert mit restriktiveren Policies

**File:** `FamilyScore/supabase/migrations/20260515_initial_schema.sql:273-275`
**Issue:** Die Policy `"Admin verwaltet Familienmitglieder"` verwendet `for all` ohne eine spezifischere WITH CHECK-Klausel fuer INSERT. In Supabase ist `using` fuer INSERT wirkungslos (gilt nur fuer SELECT/UPDATE/DELETE); `with check` wird fuer INSERT benoetigt. Die `for all`-Policy ohne `with check` verwendet standardmaessig den `using`-Ausdruck auch als `with check` — technisch korrekt, aber implizit und leicht missverstaendlich.

Darueber hinaus koennte ein Admin einer Familie theoretisch einen `family_members`-Eintrag fuer einen User anlegen, der keiner Familie angehoert (da `id` eine FK auf `auth.users` ist, nicht auf eine bestimmte Familie). Das ist wohl kein Angriffsszenario, aber eine unklare Policy-Semantik.

```sql
-- FIX: for all in explizite Einzel-Policies aufteilen, mit check explizit angeben
create policy "Admin liest Familienmitglieder"
  on public.family_members for select to authenticated
  using (public.is_family_admin(family_id));

create policy "Admin entfernt Familienmitglieder"
  on public.family_members for delete to authenticated
  using (public.is_family_admin(family_id));

-- INSERT und UPDATE bereits durch separate Policies abgedeckt
```

---

## Info

### IN-01: assertionFailure in DEBUG-Prueffunktionen wird in Release-Builds zu einem No-Op

**File:** `FamilyScore/FamilyScore/FamilyScoreApp.swift:15-24`
**Issue:** `assertionFailure()` wird in Release-Builds vom Swift-Compiler entfernt. Die Fehlerpruefung der App Group ist bereits in `#if DEBUG` eingebettet, daher ist das kein Produktionsproblem. Zur Klarheit: `assert(result, ...)` in Zeile 24 hat denselben Effekt. Keine Aenderung noetig, nur ein Hinweis zur Erwartung.

**Empfehlung:** Kein Handlungsbedarf — das Verhalten ist korrekt und das gesamte Pruef-Setup ist DEBUG-only.

---

### IN-02: Supabase Realtime-Publications schliessen category_config und family_invites nicht ein

**File:** `FamilyScore/supabase/migrations/20260515_initial_schema.sql:194-196`
**Issue:** `alter publication supabase_realtime add table` ist nur fuer `activity_entries`, `weekly_summaries` und `family_members` konfiguriert. `category_config` und `family_invites` sind nicht in Realtime. Das ist fuer Phase 1 beabsichtigt, da Realtime in Phase 5 vollstaendig implementiert wird. Zu beachten: `family_invites` wird vermutlich nie Realtime benoetigen; `category_config`-Aenderungen koennten in Phase 5 relevant werden.

**Empfehlung:** In Phase 5 (Realtime & Widgets) pruefen, ob `category_config` zu den Realtime-Publications hinzugefuegt werden soll. Kein Handlungsbedarf jetzt.

---

_Reviewed: 2026-05-15T21:03:29Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
