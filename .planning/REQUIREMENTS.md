# Family Score — v1 Requirements

## v1 Requirements

### AUTH — Authentication & Onboarding

- [ ] **AUTH-01**: User kann sich mit E-Mail + Passwort registrieren und einloggen
- [ ] **AUTH-02**: User kann sich mit Sign in with Apple registrieren und einloggen
- [ ] **AUTH-03**: User bleibt über App-Neustarts hinweg eingeloggt (Auth-Token-Persistenz)
- [ ] **AUTH-04**: User kann sich ausloggen

### FAM — Family Management

- [ ] **FAM-01**: Erster User einer Familie kann eine Familiengruppe erstellen und wird automatisch Admin
- [ ] **FAM-02**: Admin kann einen Einladungscode generieren; andere User können damit der Familiengruppe beitreten
- [ ] **FAM-03**: Admin kann Familienmitglieder entfernen
- [ ] **FAM-04**: Admin kann die Rolle eines Mitglieds ändern (Admin / Erwachsen / Kind-vereinfacht)
- [ ] **FAM-05**: Jedes Familienmitglied hat ein Profil mit Name, Avatar-Farbe und Rolle

### LOG — Activity Logging

- [ ] **LOG-01**: User kann eine Aktivität mit Timer erfassen (Start/Stop) — Zeit wird automatisch berechnet
- [ ] **LOG-02**: User kann eine Aktivität retroaktiv eintragen: Kategorie + Dauer in Minuten + optionaler Titel
- [ ] **LOG-03**: User kann einem Eintrag einen freien Titel geben (z.B. "Küche geputzt")
- [ ] **LOG-04**: User kann Einträge für Kinder-Profile erstellen (Eltern-managed)
- [ ] **LOG-05**: User kann einen Eintrag löschen (nur eigene, Admins dürfen alle)
- [ ] **LOG-06**: Aktivitäten werden einer von 4 Kategorien zugeordnet: Haushalt, Hobby/Freizeit, Besorgungen, Arbeit/Schule

### DASH — Dashboard & Statistics

- [ ] **DASH-01**: Hauptansicht zeigt persönliche Ringe für heute: Pflicht-Ring (Haushalt + Besorgungen + Arbeit), Freizeit-Ring (Hobby), Score-Ring
- [ ] **DASH-02**: Familienvergleich-Ansicht zeigt alle Mitglieder nebeneinander mit heutiger Bilanz (Stunden Pflicht vs. Freizeit + Score)
- [ ] **DASH-03**: Wochenbilanz-Ansicht zeigt Pflicht vs. Freizeit für alle Mitglieder diese Woche + Wochensieger
- [ ] **DASH-04**: Gesamt-Statistiken: alle Stunden und Punkte seit App-Start pro Person
- [ ] **DASH-05**: Aktivitäts-Feed: chronologische Liste aller Einträge der Familie heute

### SCORE — Punkte-System

- [ ] **SCORE-01**: Jede Aktivitätskategorie hat einen konfigurierbaren Punkte-Multiplikator (Punkte = Minuten × Multiplikator)
- [ ] **SCORE-02**: Score wird als Summe aller Aktivitäts-Punkte berechnet (append-only, kein mutabler total_score)
- [ ] **SCORE-03**: Score wird täglich und wöchentlich aggregiert und in der UI angezeigt

### WIDGET — Widgets

- [ ] **WIDGET-01**: Lock-Screen-Widget (accessoryCircular): zeigt meinen heutigen Score-Ring
- [ ] **WIDGET-02**: Lock-Screen-Widget (accessoryRectangular): zeigt Schnelleintrag — Kategorie antippen startet Timer oder öffnet retroaktiven Eintrag
- [ ] **WIDGET-03**: Home-Screen-Widget groß: Familienübersicht mit Score + Ranking aller Mitglieder
- [ ] **WIDGET-04**: Home-Screen-Widget groß: Quick-Entry — Kategorie-Buttons die eine Aktivität sofort starten (AppIntent, iOS 17+)
- [ ] **WIDGET-05**: Home-Screen-Widget mittel: Meine 3 persönlichen Ringe

### KID — Kinder-Features

- [ ] **KID-01**: Kinder-Profile können von Eltern erstellt und verwaltet werden (kein eigenes Gerät nötig)
- [ ] **KID-02**: Kinder-Modus (vereinfachte UI): Kind sieht nur eigene Aufgaben + Score, große Buttons, einfache Navigation
- [ ] **KID-03**: UI-Modus ist pro Familienmitglied in den Settings einstellbar (Erwachsen / Kind-vereinfacht)

### SETTINGS — Einstellungen

- [ ] **SETTINGS-01**: Kategorien können pro Familie an-/abgewählt werden (nicht aktive Kategorien erscheinen nirgends)
- [ ] **SETTINGS-02**: Punkte-Multiplikator pro Kategorie ist konfigurierbar (Standard-Werte als Voreinstellung)
- [ ] **SETTINGS-03**: Familienmitglieder-Verwaltung: einladen (Code generieren), entfernen, Rolle ändern, Kinder-Modus umschalten

### SYNC — Real-time & Push

- [ ] **SYNC-01**: Score und Ringe anderer Familienmitglieder aktualisieren live ohne App-Neustart (Supabase Realtime)
- [ ] **SYNC-02**: Aktivitäts-Feed aktualisiert live wenn ein Familienmitglied etwas einträgt
- [ ] **SYNC-03**: Push-Notification wenn ein Familienmitglied eine Aktivität einträgt (opt-in)

---

## v2 — Deferred

- Wochen-Reset-Tag konfigurierbar (Montag/Sonntag) — v1 nutzt Montag als Standard
- Vollständige Teenager-/Erwachsenen-UI-Progression für Kinder-Accounts (v1: nur zwei Modi)
- Streak-System mit Grace Periods
- Rotations-/Aufgaben-Zuweisungssystem (wer ist diese Woche für Kochen zuständig?)
- Monatlicher Review / Zusammenfassung
- Zeitgerechtigkeit-Bilanz-Dashboard (Fairness-Sicht für Erwachsene — braucht UX-Forschung)
- Sign in with Google
- Apple Watch App
- Android / Cross-Platform

## Out of Scope

- KI-generierte Aufgaben oder Empfehlungen — bewusst kein AI-Feature-Bloat
- Einkaufslisten, Familenchat, Mahlzeitenplanung — andere Apps, nicht diese
- Echtes Geld / Taschengeld-System — zu komplex, zu viel Regulierung
- Öffentliche Profile / Social Sharing — App ist rein privat/familienintern
- Real-Money-Abo zum Launch — kostenlos starten

---

## Traceability

| REQ-ID | Phase | Status |
|--------|-------|--------|
| AUTH-01…04 | — | Not mapped |
| FAM-01…05 | — | Not mapped |
| LOG-01…06 | — | Not mapped |
| DASH-01…05 | — | Not mapped |
| SCORE-01…03 | — | Not mapped |
| WIDGET-01…05 | — | Not mapped |
| KID-01…03 | — | Not mapped |
| SETTINGS-01…03 | — | Not mapped |
| SYNC-01…03 | — | Not mapped |

*Total: 36 v1 requirements*
