---
status: partial
phase: 01-foundation
source: [01-VERIFICATION.md]
started: 2026-05-15
updated: 2026-05-15
---

## Current Test

[Wartet auf Mac-Verifikation]

## Tests

### 1. Xcode-Projekt erstellen und bauen (SC-1 + SC-2)

expected: App baut auf Mac mit Xcode (BUILD SUCCEEDED), beide Targets vorhanden (FamilyScore + FamilyScoreWidgetExtension). App Group auf echtem Gerät funktioniert: `[Phase1] App Group Test: PASS` in Xcode Console.
result: [pending]

Schritte laut `01-01-SUMMARY.md` → Abschnitt "Manuelle Xcode-Schritte":
1. File > New > Project → iOS App → Product Name: FamilyScore, Bundle ID: com.familyscore
2. File > New > Target → Widget Extension → FamilyScoreWidgetExtension
3. App Group Entitlements in beiden Targets konfigurieren (group.com.familyscore)
4. Config.xcconfig als Configuration File zuweisen
5. FamilyScoreKit als lokales Package hinzufügen (nur App Target, NICHT Widget)
6. Secrets.xcconfig mit echten Supabase-Werten befüllen

### 2. Supabase Connection Test (SC-3)

expected: App im Simulator starten → Xcode Console zeigt:
```
[Phase1] Supabase Connection PASS — families returned 0 rows
[Phase1] weekly_summaries table exists PASS — 0 rows
```
result: [pending]

## Summary

total: 2
passed: 0
issues: 0
pending: 2
skipped: 0
blocked: 0

## Gaps
