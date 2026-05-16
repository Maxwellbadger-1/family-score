# Family Score

## What This Is

Eine native iPhone-App für Familien, die Zeitgerechtigkeit sichtbar macht: Wer hat heute wie viele Stunden in Haushalt, Besorgungen und Arbeit investiert — und wer hat wie viel Freizeit und Hobby-Zeit bekommen? Family Score kombiniert ein Punkte-/Score-System mit einer fairen Zeitbilanz-Visualisierung im Apple-Health-Stil.

## Core Value

Familienmitglieder sollen auf einen Blick sehen können, ob Pflichten und Freizeit fair aufgeteilt sind — Transparenz schafft Fairness ohne Diskussion.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Familiengruppe erstellen und Mitglieder einladen (Multi-User via Supabase Auth)
- [ ] Aktivitäten eintragen: per Timer (Start/Stop) oder retroaktiv (Kategorie + Dauer)
- [ ] Kategorien: Haushalt, Hobby/Freizeit, Besorgungen/Errands, Arbeit/Schule — alle einzeln in Settings an-/abwählbar
- [ ] Punkte-System: zeitbasiert + aufgabengewichtet (jede Aufgabe hat konfigurierbaren Punkt-Wert) + Eltern-vergabe
- [ ] Zeitbilanz-Dashboard: Pflicht-Stunden vs. Freizeit-Stunden pro Person sichtbar machen
- [ ] Familienvergleich: Wer hat heute/diese Woche wie viel geleistet und wie viel Freizeit gehabt
- [ ] Wochen-Reset mit Archiv; Gesamt-Score und Stunden seit Beginn
- [ ] Kinder-UI-Modus per Settings: Parent-managed → Kind-vereinfacht → Erwachsenen-UI
- [ ] Live-Updates: Einträge anderer Familienmitglieder erscheinen sofort (Supabase Realtime)
- [ ] Widgets: Großes Quick-Entry-Widget, großes Kombinations-Widget (Score + Ranking + Stats), kleine Stats-Widgets
- [ ] Lock-Screen-Widget-Unterstützung (iOS 16+)
- [ ] Apple-Health-/Fitness-Style Design: Rings, Dark Mode, saubere Datenviz, native iOS-Qualität
- [ ] Settings: Kategorien, Punkte-Gewichtung, Kinder-Modus, Wochen-Reset-Tag, Familienmitglieder verwalten

### Out of Scope

- Android-Version — iOS-first, nativ SwiftUI; kein React Native / Flutter
- KI-generierte Aufgabenvorschläge — bewusst kein AI-Sloppy-Overhead
- Bezahlte Abo-Features zum Launch — kostenlos starten, Supabase Free Tier
- Social-Sharing / Public Profiles — rein privat/Familie

## Context

- Wird mit Claude Code gebaut (kein Cursor, kein separater AI-Editor)
- Zielgruppe: eigene Familie des Entwicklers — Eltern + Kinder verschiedener Altersgruppen
- Design-Referenz: Apple Health / Fitness (Rings, Dark Mode, klare Charts, hochwertige native iOS-Ästhetik)
- Kinder-UI muss drei Modi unterstützen, die wachsen: Eltern tragen für Kinder ein → Kind hat vereinfachte Ansicht → Kind bekommt Erwachsenen-UI
- Alle Tracking-Kategorien müssen in Settings ein-/ausschaltbar sein (family-by-family konfigurierbar)

## Constraints

- **Tech Stack**: SwiftUI + WidgetKit (nativ iOS) — keine Cross-Platform-Frameworks
- **Backend**: Supabase (PostgreSQL + Realtime + Auth) — Free Tier muss ausreichen
- **Platform**: iOS 16+ (für Lock-Screen-Widgets zwingend)
- **Qualität**: Kein Feature-Bloat, kein AI-Sloppy-Code — lieber weniger, aber poliert
- **Entwicklung**: Solo mit Claude Code, kein externes Team
- **Entwicklungsumgebung**: Windows 11 only — kein Mac, kein lokales Xcode, kein iOS Simulator. Builds und Tests laufen ausschließlich via GitHub Actions (CI-First). UI-Tests via Appetize.io. Physische Geräte-Tests via Sideloadly (Windows → iPhone per USB). App Store Submission via GitHub Actions + fastlane (macOS-Runner, kein lokaler Mac nötig).

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| SwiftUI statt React Native/Flutter | Widgets + Lock Screen brauchen native WidgetKit-Integration; Apple-Health-Look nur nativ erreichbar | — Pending |
| Supabase statt Neon oder Firebase | Neon hat kein eingebautes Realtime; Firebase ist Google (sunset-Risiko); Supabase hat Realtime + Auth + PostgreSQL auf Free Tier | — Pending |
| iOS-first, kein Android | Ressourcen fokussieren; nativ > Cross-Platform für diese App | — Pending |
| Kein AI-Feature zum Launch | Bewusste Design-Entscheidung gegen Feature-Bloat | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-15 after initialization*
