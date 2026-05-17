# Phase 6: Settings & Polish — Research

**Researched:** 2026-05-17
**Domain:** SwiftUI Settings-UI, Kategorie-Konfiguration, Kinder-UI-Modus, App Store Submission via fastlane + GitHub Actions, Privacy Manifest
**Confidence:** HIGH (Kernbereiche), MEDIUM (fastlane-Ersteinrichtung ohne Mac)

---

## Summary

Phase 6 schließt das Projekt ab: Admins bekommen eine Settings-UI zum Konfigurieren von Kategorien und Punkt-Multiplikatoren, die `child`-Rolle bekommt eine vereinfachte UI, und die App wird über GitHub Actions + fastlane ohne Mac in den App Store hochgeladen.

**Alle vier technischen Hauptbereiche** sind gut umsetzbar ohne Mac:

1. **Kategorie-Toggle (SETTINGS-01):** `category_config`-Tabelle existiert bereits in Phase 1 mit `is_enabled`-Spalte. Admin-Update via Supabase REST (`.update().eq("id")`), RLS-Policy "Admin verwaltet Kategorien" ist bereits live. Views filtern nach `is_enabled == true`. Widget-Update: nach jedem Toggle `WidgetCenter.shared.reloadAllTimelines()`.

2. **Punkt-Multiplikator (SETTINGS-02):** `point_weight`-Spalte in `category_config` bereits vorhanden. Update ändert nur zukünftige Einträge, da Punkte bei `INSERT` in `activity_entries` vorberechnet werden (`points = duration_minutes * point_weight`). Historische Einträge bleiben unberührt — kein Migration-Aufwand.

3. **Kind-vereinfacht UI (KID-02/KID-03):** `MemberRole.child` ist bereits definiert, `change_member_role`-RPC existiert aus Phase 3. Das UI-Routing braucht nur eine Environment-basierte Bedingung: wenn der eingeloggte User `role == .child`, zeige `KindDashboardView` statt `MainDashboardView`. Admin kann Rolle in Settings ändern ohne Device-Handoff.

4. **App Store Submission:** Vollständig via GitHub Actions möglich. Benötigt: neues privates GitHub-Zertifikats-Repo für fastlane match, App Store Connect API Key (.p8), `PrivacyInfo.xcprivacy`. Ein separater Release-Workflow (.github/workflows/release.yml) ergänzt den bestehenden build.yml.

**Primäre Empfehlung:** `CategoryService` als neuen Service hinzufügen (gleiche Muster wie FamilyService), Settings-Views mit Admin-Guard, `KindDashboardView` als vereinfachten Wrapper, fastlane match für Zertifikate.

---

<phase_requirements>
## Phase Requirements

| ID | Beschreibung | Research-Grundlage |
|----|--------------|-------------------|
| SETTINGS-01 | Kategorien können pro Familie an-/abgewählt werden (inaktive Kategorien erscheinen nirgends) | `category_config.is_enabled` existiert in DB; RLS-Policy schon live; Widget-Refresh via `WidgetCenter` |
| SETTINGS-02 | Punkte-Multiplikator pro Kategorie konfigurierbar (betrifft nur zukünftige Einträge) | `point_weight` in `category_config`; Punkte werden bei INSERT vorberechnet; keine DB-Migration nötig |
| KID-02 | Kind-Modus: nur eigene Aufgaben + Score, große Buttons, kein Familienvergleich | `MemberRole.child` existiert; Environment-basiertes View-Routing; neue `KindDashboardView` |
| KID-03 | UI-Modus per Settings änderbar durch Admin, ohne Device-Handoff | `change_member_role`-RPC aus Phase 3 wiederverwendbar; Admin-Settings-Screen |
</phase_requirements>

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Begründung |
|------------|-------------|----------------|-----------|
| Kategorie-Toggle/Gewichtung speichern | API / Backend (Supabase) | — | RLS-Policy "Admin verwaltet Kategorien" erzwingt Berechtigungsprüfung serverseitig |
| Aktivierte Kategorien filtern (UI) | Frontend (SwiftUI) | — | View filtert bereits geladene `category_config` nach `is_enabled`; kein extra Endpoint |
| Aktivierte Kategorien filtern (Widgets) | App (WidgetDataWriter) | Widget-Extension | App schreibt nur aktivierte Kategorien in App Group; Widget hat keine DB-Sicht |
| Kind-UI Routing | Frontend (SwiftUI) | — | Rollencheck via `AppState.currentMember.role`; reines View-Routing |
| UI-Modus ändern (Admin) | API / Backend (RPC) | Frontend (FamilyService) | `change_member_role`-RPC, bereits implementiert in Phase 3 |
| App Store Submission | CI/CD (GitHub Actions) | Fastlane (macOS-Runner) | Kein lokaler Mac nötig; macOS-Runner übernimmt Signierung + Upload |
| Privacy Manifest | Statische Ressource (Xcode) | — | `PrivacyInfo.xcprivacy`-Datei im App-Target; keine Runtime-Logik |

---

## Standard Stack

### Core

| Bibliothek/Tool | Version | Zweck | Begründung |
|-----------------|---------|-------|-----------|
| supabase-swift | 2.46.0 | Category CRUD, RLS-gesicherter Admin-Update | Bereits im Projekt; `category_config`-Tabelle direkt via REST aktualisierbar |
| SwiftUI | iOS 16+ | Settings-Views, Kind-UI | Bestehende Muster aus Phasen 2–3; `@EnvironmentObject`/`@Published` |
| fastlane | 2.x aktuell | Zertifikate, Build, Upload zu App Store Connect | Industrie-Standard für iOS CI/CD; macOS-Runner in GitHub Actions |
| fastlane match | (in fastlane) | Git-basiertes Zertifikats-Management | Verschlüsseltes privates Zertifikats-Repo; kein manuelles Zertifikat-Handling |
| fastlane deliver / upload_to_app_store | (in fastlane) | App Store Submission | Vollautomatisch via App Store Connect API Key (.p8) |

### Supporting

| Bibliothek/Tool | Zweck | Wann verwenden |
|-----------------|-------|---------------|
| `app_store_connect_api_key` Fastlane-Action | JWT-Authentifizierung gegen App Store Connect API ohne Apple-ID/2FA | In jedem Release-Lane; ersetzt username/password-Auth |
| `setup_ci` Fastlane-Action | Temporäre Keychain für CI erstellen | Pflicht in GitHub-Actions-Lanes, verhindert Build-Freeze |
| `WidgetCenter.shared.reloadAllTimelines()` | Widget-Refresh nach Kategorie-Änderung | Immer nach `category_config`-Update aufrufen |
| `PrivacyInfo.xcprivacy` | Privacy Manifest | Im App-Target (nicht Widget Extension); ab iOS 17.2-Requirement aber für alle App Store-Uploads Pflicht seit Mai 2024 |

### Alternatives Considered

| Standard | Alternative | Tradeoff |
|----------|-------------|----------|
| fastlane match (git) | Manuelles Zertifikats-Management | Match automatisiert Rotation, kein manueller Apple-Portal-Zugriff nötig nach Einrichtung |
| fastlane match (git) | fastlane match (S3/Google Cloud) | Git-Repo ist einfacher, kostenlos, keine zusätzliche Cloud-Infrastruktur |
| `app_store_connect_api_key`-Action | Apple-ID + App-Passwort | API-Key ist stabiler (kein 2FA-Problem in CI), empfohlen seit 2021 |
| View-Routing via Environment | Separate App-Instanz für Kind | Environment ist einfacher; kein separates App-Target nötig |

---

## Architecture Patterns

### System Architecture Diagram

```
Admin öffnet Settings
    │
    ├── SettingsView (Admin-only Guard via currentMember.role == .admin)
    │       │
    │       ├── CategorySettingsView
    │       │       │
    │       │       ├── Toggle is_enabled → CategoryService.toggleCategory()
    │       │       │       └── Supabase: UPDATE category_config SET is_enabled
    │       │       │               └── RLS: Admin-Policy prüft Berechtigung
    │       │       │
    │       │       └── Stepper point_weight → CategoryService.updateWeight()
    │       │               └── Supabase: UPDATE category_config SET point_weight
    │       │
    │       └── MemberSettingsView (Admin-Mitgliederverwaltung, wiederverwendet Phase-3-Views)
    │               └── change_member_role RPC → FamilyService.changeMemberRole()
    │
    └── Nach jedem category_config-Update:
            └── WidgetCenter.shared.reloadAllTimelines()
                    └── Widget liest App Group → zeigt nur aktivierte Kategorien

User mit role == .child öffnet App
    │
    └── RootView prüft AppState.currentMember.role
            ├── .admin / .adult → MainTabView (voller Funktionsumfang)
            └── .child → KindDashboardView
                    ├── Nur eigener Score (kein Familienvergleich)
                    ├── Nur eigene Aktivitätsliste
                    ├── Große Tap-Targets (min. 44pt)
                    └── Kein Settings-Tab
```

### Recommended Project Structure (Ergänzungen zu Phase 6)

```
FamilyScore/
├── Services/
│   ├── CategoryService.swift        # NEU: category_config CRUD
│   └── FamilyService.swift          # bestehend (Phase 3)
├── Models/
│   └── CategoryConfig.swift         # NEU: Decodable-Struct für category_config
├── Views/
│   ├── Settings/
│   │   ├── SettingsView.swift        # NEU: Root-Settings mit Admin-Guard
│   │   ├── CategorySettingsView.swift # NEU: Toggle + Multiplikator
│   │   └── MemberSettingsView.swift  # NEU: Rollen-/Modus-Änderung (wraps Phase-3-Views)
│   └── Kid/
│       └── KindDashboardView.swift   # NEU: vereinfachte Kind-UI
├── Resources/
│   └── PrivacyInfo.xcprivacy         # NEU: Privacy Manifest
fastlane/
├── Fastfile                          # NEU: release_appstore-Lane
├── Matchfile                         # NEU: git_url, app_identifier
├── Appfile                           # NEU: app_identifier, apple_id
└── Deliverfile                       # NEU: metadata-Optionen
.github/workflows/
├── build.yml                         # bestehend (Tests + Appetize)
└── release.yml                       # NEU: App Store-Submission-Workflow
```

### Pattern 1: CategoryService — Kategorie-Konfiguration lesen und schreiben

**Was:** Thin Service-Wrapper um `category_config`-Tabelle. Liest aktivierte Kategorien, schreibt Toggles und Gewichtungen.
**Wann:** Wird von `CategorySettingsView` (Admin) und `ActivityService` (Log-UI) verwendet.

```swift
// Source: Supabase Swift docs — https://supabase.com/docs/reference/swift/update
// + RLS-Policy "Admin verwaltet Kategorien" aus 20260515_initial_schema.sql

@MainActor
final class CategoryService: ObservableObject {
    @Published private(set) var categories: [CategoryConfig] = []

    func fetchCategories(familyId: UUID) async {
        do {
            let fetched: [CategoryConfig] = try await supabase
                .from("category_config")
                .select()
                .eq("family_id", value: familyId.uuidString)
                .order("sort_order", ascending: true)
                .execute()
                .value
            categories = fetched
        } catch {
            // Fehlerbehandlung wie FamilyService-Muster
        }
    }

    /// Nur aktivierte Kategorien — für Log-UI und Widget-Writer
    var enabledCategories: [CategoryConfig] {
        categories.filter { $0.isEnabled }
    }

    func toggleCategory(id: UUID, isEnabled: Bool) async throws {
        struct Patch: Encodable {
            let is_enabled: Bool
            let updated_at: Date
        }
        try await supabase
            .from("category_config")
            .update(Patch(is_enabled: isEnabled, updated_at: Date()))
            .eq("id", value: id.uuidString)
            .execute()
        // Lokalen State optimistisch aktualisieren
        if let idx = categories.firstIndex(where: { $0.id == id }) {
            categories[idx].isEnabled = isEnabled
        }
        // Widget-Update erzwingen
        WidgetCenter.shared.reloadAllTimelines()
    }

    func updateWeight(id: UUID, weight: Double) async throws {
        struct Patch: Encodable {
            let point_weight: Double
            let updated_at: Date
        }
        try await supabase
            .from("category_config")
            .update(Patch(point_weight: weight, updated_at: Date()))
            .eq("id", value: id.uuidString)
            .execute()
        if let idx = categories.firstIndex(where: { $0.id == id }) {
            categories[idx].pointWeight = weight
        }
    }
}
```

### Pattern 2: Kind-UI-Routing via AppState

**Was:** RootView prüft Rolle des eingeloggten Users und routet zu `KindDashboardView` oder `MainTabView`.
**Wann:** Immer wenn `AppState.currentMember.role == .child`.

```swift
// Source: [ASSUMED] — SwiftUI @EnvironmentObject-Pattern, iOS 16-kompatibel

// In RootView (nach Login + FamilyStatus geladen):
Group {
    if let member = appState.currentMember {
        switch member.role {
        case .child:
            KindDashboardView()
                .environmentObject(activityService)
        case .admin, .adult:
            MainTabView()
                .environmentObject(activityService)
                .environmentObject(categoryService)
        }
    }
}

// KindDashboardView: vereinfacht, keine Familie-Vergleichs-Views
struct KindDashboardView: View {
    @EnvironmentObject var activityService: ActivityService
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Großer persönlicher Score-Ring (kein Vergleich)
                PersonalRingView(userId: currentUserId)
                    .frame(minHeight: 200)
                
                // Eigene heutige Aktivitäten (kein Familienvergleich)
                MyActivitiesListView(userId: currentUserId)
            }
            .navigationTitle("Mein Score")
            // Kein TabView — keine Settings-Tabs
        }
    }
}
```

### Pattern 3: Admin-Guard für Settings

**Was:** Settings ist nur für Admins erreichbar. Kein eigener NavigationPath benötigt — einfache Bedingung.
**Wann:** Überall wo Admin-only-Funktionen angezeigt werden.

```swift
// In MainTabView oder SettingsView:
if appState.currentMember?.role == .admin {
    Tab("Einstellungen", systemImage: "gear") {
        SettingsView()
    }
}
// [ASSUMED] — kein offizieller Apple-Code; Standard-SwiftUI-Pattern
```

### Pattern 4: fastlane match + App Store Connect API Key

**Was:** Release-Lane für GitHub Actions ohne Apple-ID-Passwort/2FA.
**Wann:** App Store-Submission-Workflow (`release.yml`).

```ruby
# Source: https://docs.fastlane.tools/app-store-connect-api/
# Source: https://brightinventions.pl/blog/ios-testflight-github-actions-fastlane-match/

# fastlane/Fastfile
default_platform(:ios)

platform :ios do
  lane :release_appstore do
    # 1. App Store Connect API Key laden (keine 2FA nötig)
    app_store_connect_api_key(
      key_id: ENV["ASC_KEY_ID"],
      issuer_id: ENV["ASC_ISSUER_ID"],
      key_content: ENV["ASC_KEY"],   # Inhalt der .p8-Datei als String
      in_house: false
    )

    # 2. Temporäre Keychain für CI
    setup_ci

    # 3. Zertifikate und Profile aus Zertifikats-Repo laden
    match(
      type: "appstore",
      readonly: is_ci,
      git_url: ENV["MATCH_GIT_URL"],
      app_identifier: "com.familyscore"
    )

    # 4. App bauen (Release-Konfiguration)
    build_app(
      project: "FamilyScore/FamilyScore.xcodeproj",
      scheme: "FamilyScore",
      configuration: "Release",
      export_method: "app-store",
      cloned_source_packages_path: "~/spm-packages"
    )

    # 5. Zu TestFlight hochladen
    upload_to_testflight(skip_waiting_for_build_processing: true)
  end
end
```

```yaml
# .github/workflows/release.yml (neu)
name: App Store Release
on:
  workflow_dispatch:    # Manueller Trigger (kein Auto-Release bei Push)

jobs:
  release:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode 16
        run: |
          XCODE=$(ls /Applications/ | grep "^Xcode_16" | sort -V | tail -1)
          sudo xcode-select -s "/Applications/$XCODE/Contents/Developer"
      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.4'
          bundler-cache: true
      - name: Install XcodeGen + xcpretty
        run: brew install xcodegen && gem install xcpretty --no-document
      - name: Create Secrets.xcconfig
        run: |
          SUPABASE_HOST=$(echo "${{ secrets.SUPABASE_URL_SECRET }}" | sed 's|https://||')
          cat > FamilyScore/Config/Secrets.xcconfig << EOF
          SUPABASE_URL_SECRET = $SUPABASE_HOST
          SUPABASE_KEY_SECRET = ${{ secrets.SUPABASE_KEY_SECRET }}
          EOF
      - name: Generate Xcode Project
        working-directory: FamilyScore
        run: xcodegen generate --spec project.yml
      - name: Run fastlane release
        run: bundle exec fastlane release_appstore
        env:
          ASC_KEY_ID: ${{ secrets.ASC_KEY_ID }}
          ASC_ISSUER_ID: ${{ secrets.ASC_ISSUER_ID }}
          ASC_KEY: ${{ secrets.ASC_KEY }}
          MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
          MATCH_GIT_URL: ${{ secrets.MATCH_GIT_URL }}
          MATCH_GIT_BASIC_AUTHORIZATION: ${{ secrets.MATCH_GIT_BASIC_AUTHORIZATION }}
```

### Pattern 5: PrivacyInfo.xcprivacy für Family Score

**Was:** Pflicht-Datei für App Store Submissions seit Mai 2024. Deklariert verwendete "Required Reason APIs".
**Für Family Score relevant:** `UserDefaults` (App Group für Widgets) und `FileTimestamp` (implizit durch URLSession/NSFileManager in supabase-swift).

```xml
<!-- FamilyScore/Resources/PrivacyInfo.xcprivacy -->
<!-- Source: https://developer.apple.com/documentation/bundleresources/privacy-manifest-files -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Kein Tracking (reine Familien-App, keine Drittanbieter-Analytics) -->
    <key>NSPrivacyTracking</key>
    <false/>

    <!-- Keine Tracking-Domains -->
    <key>NSPrivacyTrackingDomains</key>
    <array/>

    <!-- Gesammelte Daten: User-ID und Aktivitätsdaten (nur für App-Funktionalität) -->
    <key>NSPrivacyCollectedDataTypes</key>
    <array>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeUserID</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <true/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
            </array>
        </dict>
    </array>

    <!-- Required Reason APIs -->
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <!-- UserDefaults: App Group für Widget-Datenaustausch -->
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPITypeUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <!-- CA92.1: Zugriff auf UserDefaults in der eigenen App-Group -->
                <string>CA92.1</string>
            </array>
        </dict>
        <!-- FileTimestamp: Implizit durch supabase-swift (URL-Caching) -->
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPITypeFileTimestamp</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <!-- 3B52.1: Zugriff auf Timestamps von App-eigenen Dateien -->
                <string>3B52.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

**Wichtig:** Die Datei muss zum App-Target hinzugefügt werden (nicht Widget-Extension-Target). In project.yml als `resources`-Eintrag des FamilyScore-Targets eintragen.

### Anti-Patterns vermeiden

- **Kategorie-Filter client-seitig NACH dem Laden überschreiben:** Alle Queries nach `activity_entries` müssen nur auf aktivierten Kategorien basieren. Wenn eine Kategorie deaktiviert wird, sollen Einträge nicht gelöscht werden — sie werden nur nicht mehr in neuen Log-UI und Dashboard angezeigt. Historische Daten bleiben vollständig.
- **`point_weight`-Änderung auf historische Einträge rückwirkend anwenden:** Punkte sind bei INSERT vorberechnet. Niemals `activity_entries.points` nachträglich neu berechnen — das wäre eine Breaking-Change zu Phase-1-Architektur-Entscheidung.
- **Kind-UI als separates Xcode-Target:** Ein `@EnvironmentObject`-basiertes Routing reicht; kein separates Target.
- **`match` ohne `readonly: is_ci` in CI:** Ohne `readonly` versucht match neue Zertifikate zu erstellen, was in CI-Umgebungen fehlschlägt oder unerwünschte Zertifikate anlegt.
- **Apple-ID + App-Passwort statt API Key:** Apple-ID-Authentifizierung in CI ist fragil (2FA-Prompts, Session-Timeouts). Immer `app_store_connect_api_key`-Action verwenden.

---

## Don't Hand-Roll

| Problem | Nicht bauen | Stattdessen verwenden | Begründung |
|---------|-------------|----------------------|-----------|
| Zertifikate + Profile verwalten | Eigenes Skript das .p12/.mobileprovision herunterlädt | `fastlane match` | Match verschlüsselt, versioniert, erneuert automatisch; manuelle Verwaltung führt zu Abläufen und Build-Failures |
| App Store Upload | Eigenes `curl`-Skript gegen App Store Connect REST API | `fastlane upload_to_app_store` oder `upload_to_testflight` | Transporter-Protokoll-Details, Chunk-Upload, Retry-Logik — fastlane implementiert das seit Jahren |
| JWT-Authentifizierung gegen App Store Connect API | Eigene JWT-Generierung mit .p8-Schlüssel | `app_store_connect_api_key`-Action | JWT hat 20-Minuten-Ablauf, spezifisches Format; Action handhabt das automatisch |
| Privacy Manifest generieren | Eigenes Skript | `PrivacyInfo.xcprivacy`-Datei in Xcode erstellen | Statische Datei; keine Dynamik nötig |
| Rollenbasierter Access in UI | Eigenes Permission-Framework | SwiftUI `@EnvironmentObject` + `role`-Enum-Check | Drei Rollen, binäre Checks; kein Framework-Overhead nötig |

---

## Common Pitfalls

### Pitfall 1: fastlane match — Ersteinrichtung erfordert einmalig Mac (oder GitHub Actions-Job)

**Was geht schief:** `fastlane match init` + erster `fastlane match appstore` (der Zertifikate erstellt und ins Zertifikats-Repo pusht) benötigt eine Session mit Apple Developer Portal. Auf Windows ohne Mac kann `fastlane` nicht direkt ausgeführt werden.

**Warum es passiert:** fastlane ist ein Ruby-Gem und läuft nativ auf macOS; die Apple-Developer-Portal-Kommunikation erfordert native macOS-Tools (Spaceship/Fastlane).

**Wie vermeiden:** Ersteinrichtung via einem dedizierten GitHub-Actions-Job der einmalig manuell getriggert wird (`workflow_dispatch`), mit `match(readonly: false)` und Apple-ID als Secrets. Alternativ: Zertifikat einmalig manuell über Apple Developer Portal erstellen und manuell ins Zertifikats-Repo laden (`match import`-Subcommand).

**Warnsignal:** `fastlane match` schlägt mit "No certificates found in repository" fehl — bedeutet, Ersteinrichtung wurde nicht abgeschlossen.

**Confidence:** MEDIUM — [CITED: https://docs.fastlane.tools/actions/match/]

---

### Pitfall 2: `MATCH_GIT_BASIC_AUTHORIZATION` vs. SSH-Key für Zertifikats-Repo

**Was geht schief:** HTTPS-Authentifizierung mit Personal Access Token (PAT) ist die einfachste Option, aber GitHub PATs können ablaufen. SSH Deploy Keys laufen nicht ab, sind aber komplizierter einzurichten.

**Empfehlung:** GitHub PAT mit `repo`-Scope als HTTPS-Auth: `echo -n "username:PAT" | base64` → als `MATCH_GIT_BASIC_AUTHORIZATION`-Secret. PAT-Ablaufdatum auf "No expiration" setzen (nur für diesen einzigen Zweck: Zertifikats-Repo).

**Confidence:** MEDIUM — [CITED: https://docs.fastlane.tools/actions/match/]

---

### Pitfall 3: `category_config`-RLS-Policy gilt für Admin, nicht für Widget-Extension

**Was geht schief:** Die Widget-Extension liest Kategorien nicht direkt aus Supabase (kein SDK in Widget). Wenn eine Kategorie deaktiviert wird und die App das Widget-Cache nicht aktualisiert, zeigt das Widget weiterhin die alte Kategorie.

**Wie vermeiden:** Nach jedem `toggleCategory()`-Call in `CategoryService`:
1. Lokalen `categories`-Array aktualisieren
2. `WidgetDataWriter.update(enabledCategories: categoryService.enabledCategories)` aufrufen
3. `WidgetCenter.shared.reloadAllTimelines()` aufrufen

Der WidgetDataWriter aus Phase 5 muss die aktivierten Kategorien in die `WidgetData`-Struktur einbeziehen.

**Confidence:** HIGH — [VERIFIED: Projektarchitektur aus STACK.md/ARCHITECTURE.md]

---

### Pitfall 4: Privacy Manifest — fehlende API-Deklarationen führen zu App-Rejection

**Was geht schief:** Apple lehnt App-Store-Submissions ab, wenn `NSPrivacyAccessedAPITypes` unvollständig ist. `supabase-swift` nutzt intern `URLSession` und möglicherweise `FileManager` — deren Required-Reason-APIs müssen auch deklariert werden, wenn sie durch transitive Abhängigkeiten genutzt werden.

**Wie vermeiden:**
- Supabase liefert ab v2.x ein eigenes Privacy Manifest mit (`PrivacyInfo.xcprivacy` im SDK) — prüfen ob es in der aktuellen Version (2.46.0) enthalten ist
- App-eigene Nutzung: `NSPrivacyAccessedAPITypeUserDefaults` (App Group) mit Reason `CA92.1`
- Xcode 16 erzeugt bei "Validate App" eine Warnung wenn Required APIs fehlen — diesen Check in den Release-Prozess einbauen

**Warnsignal:** App Store Connect zeigt "Missing Privacy Manifest" Email nach IPA-Upload.

**Confidence:** MEDIUM — [CITED: https://developer.apple.com/documentation/bundleresources/privacy-manifest-files]

---

### Pitfall 5: `build_app` in fastlane erfordert korrektes `export_method` + korrektes Profil

**Was geht schief:** `match(type: "appstore")` lädt ein Distribution-Profil, aber `build_app` verwendet das falsche Export-Method-Setting. Resultat: signierter IPA mit falschem Zertifikatstyp, App Store Connect lehnt ab.

**Wie vermeiden:**
```ruby
build_app(
  export_method: "app-store",   # nicht "development" oder "ad-hoc"
  export_options: {
    provisioningProfiles: {
      "com.familyscore" => "match AppStore com.familyscore",
      "com.familyscore.widget" => "match AppStore com.familyscore.FamilyScoreWidgetExtension"
    }
  }
)
```
Beide Targets (App + Widget Extension) benötigen eigene App Store Provisioning Profiles in match.

**Confidence:** MEDIUM — [CITED: https://docs.fastlane.tools/actions/match/]

---

### Pitfall 6: Child-UI verliert Zugang zu ActivityService wenn EnvironmentObject nicht injiziert

**Was geht schief:** `KindDashboardView` braucht `ActivityService` über `@EnvironmentObject`. Wenn `RootView` bei der Fallback-Route (`case .child:`) das `environmentObject` vergisst, crasht die App mit "No ObservableObject of type ActivityService found".

**Wie vermeiden:** Beide Pfade (Admin/Adult und Child) müssen identische `@EnvironmentObject`-Injektionen erhalten. Template aus Phase 3 (MemberListView) als Referenz nutzen.

**Confidence:** HIGH — [ASSUMED, aber bekanntes SwiftUI-Muster aus PITFALLS.md]

---

### Pitfall 7: App Store — `get-task-allow`-Entitlement darf in Release nicht gesetzt sein

**Was geht schief:** Development-Builds haben `com.apple.security.get-task-allow = true` (erlaubt Debugger-Attachment). Wenn das in einem Distribution-Build bleibt, lehnt App Store Connect ab.

**Wie vermeiden:**
- fastlane `match(type: "appstore")` + `build_app(export_method: "app-store")` setzt automatisch das richtige Profil
- Nach dem Build prüfen: `codesign -dvvv FamilyScore.app` sollte `get-task-allow` nicht listen
- In `project.yml` sicherstellen, dass das Release-Entitlements-File (`.entitlements`) kein `get-task-allow` enthält

**Confidence:** HIGH — [CITED: https://developer.apple.com/documentation/bundleresources/diagnosing-issues-with-entitlements]

---

## State of the Art

| Alter Ansatz | Aktueller Ansatz | Geändert | Bedeutung |
|--------------|-----------------|----------|-----------|
| Apple-ID + App-Passwort in CI | App Store Connect API Key (.p8) | 2021 | Kein 2FA-Problem, stabiler in CI |
| `force_for_new_devices` in match | Deprecated | Mai 2025 | Nicht mehr verwenden; neue Geräte manuell im Portal hinzufügen oder Wildcard-Profile nutzen |
| `deliver` Action | `upload_to_app_store` Action | ~2020 | `deliver` ist Alias; `upload_to_app_store` ist der kanonische Name |
| Privacy Manifest optional | Pflicht seit Mai 2024 | Mai 2024 | Alle neuen App Store-Einreichungen benötigen `PrivacyInfo.xcprivacy` |
| Username/Passwort in match | `MATCH_GIT_BASIC_AUTHORIZATION` (Base64) | ~2022 | SSH oder PAT via Base64 empfohlen |

**Deprecated/Veraltet:**
- `force_for_new_devices` in fastlane match: deprecated Mai 2025, nicht verwenden
- `supabase.auth.user` (alt): in supabase-swift v2 ist es `supabase.auth.session.user` (bereits korrekt im Projekt verwendet, Supabase.swift)

---

## Assumptions Log

| # | Behauptung | Abschnitt | Risiko bei Fehler |
|---|------------|-----------|------------------|
| A1 | `ActivityService` aus Phase 4 hat eine `enabledCategoryIds`-Property oder filtert Kategorien beim Log-UI | Architecture Patterns (Pattern 1) | CategoryService-Integration in ActivityService muss ggf. angepasst werden |
| A2 | `WidgetDataWriter` aus Phase 5 akzeptiert eine Liste aktivierter Kategorien als Parameter | Common Pitfalls (Pitfall 3) | WidgetData-Struktur muss um `enabledCategoryNames` o.ä. erweitert werden |
| A3 | `AppState.currentMember` (oder ähnliche Property) enthält die Rolle des eingeloggten Users nach Phase-3-Integration | Architecture Patterns (Pattern 2) | Routing-Logik muss adjustiert werden um auf echte State-Property zu zeigen |
| A4 | supabase-swift 2.46.0 enthält bereits ein eigenes Privacy Manifest (PrivacyInfo.xcprivacy im SDK-Bundle) | Common Pitfalls (Pitfall 4) | App-eigenes Manifest muss SDK-Required-APIs ebenfalls deklarieren |
| A5 | `project.yml` (XcodeGen) kann um `PrivacyInfo.xcprivacy` als Resource erweitert werden ohne strukturelle Änderungen | Standard Stack | Falls project.yml komplexere Änderungen benötigt, muss das in Wave 0 geklärt werden |

---

## Open Questions

1. **Phase-4/5-Integrationstiefe von CategoryService**
   - Was wir wissen: `category_config`-Tabelle + RLS-Policy + 4 Standard-Kategorien existieren seit Phase 1/3
   - Unklar: Hat Phase 4 bereits einen `CategoryService` oder `CategoryModel` angelegt? Hat Phase 5 `WidgetData` um Kategorie-Informationen erweitert?
   - Empfehlung: Vor Phase-6-Planung bestehende Services in Phase 4 und 5 sichten. Falls `CategoryService` bereits existiert, nur erweitern; falls nicht, neu anlegen.

2. **fastlane match Ersteinrichtung — Mac-Verfügbarkeit**
   - Was wir wissen: Ersteinrichtung erfordert Apple-Developer-Portal-Interaktion; auf Windows nicht direkt möglich
   - Unklar: Hat der Entwickler Zugang zu einem Mac für die einmalige Ersteinrichtung (Freunde, Bibliothek, etc.)? Oder soll die Einrichtung vollständig über einen GitHub-Actions-Job erfolgen?
   - Empfehlung: Im Plan einen dedizierten "Wave 0: fastlane-Einrichtung"-Schritt vorsehen der via `workflow_dispatch` getriggert werden kann und bei Bedarf manuell überwacht wird. Alternativ: `match(readonly: false)` einmalig in CI mit Apple-ID und App-Passwort (2FA-Code als manuellen Input), danach dauerhaft readonly.

3. **Widget Extension Bundle ID für match**
   - Was wir wissen: Widget Extension hat eigene App ID (`com.familyscore.FamilyScoreWidgetExtension` oder ähnlich)
   - Unklar: Genaue Bundle ID der Widget Extension aus `project.yml`
   - Empfehlung: Vor Release-Wave `project.yml` auf Widget-Extension-Bundle-ID prüfen; match benötigt beide App-Identifiers.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| GitHub Actions macOS-Runner | App Store Build + Release | ✓ | macos-15 (im build.yml) | — |
| Xcode 16 | Release-Build mit iOS SDK | ✓ | Xcode_16 (CI) | — |
| fastlane | Release-Lane | ✗ lokal | — | GitHub Actions macOS-Runner (Ruby Gem) |
| Ruby 3.4 | fastlane | ✓ via actions/setup-ruby | 3.4 | — |
| App Store Connect API Key (.p8) | upload_to_app_store | ✗ noch nicht angelegt | — | Manuell in App Store Connect anlegen (einmalig) |
| Privates Zertifikats-Repo (GitHub) | fastlane match | ✗ noch nicht angelegt | — | Muss neu erstellt werden |
| Apple Developer Account (bezahlt, $99/Jahr) | App Store Distribution-Zertifikat | Annahme: ✓ | — | Ohne bezahlten Account kein App Store-Upload |

**Fehlende Dependencies ohne Fallback:**
- App Store Connect API Key (.p8): muss einmalig in App Store Connect unter "Users and Access → Integrations → App Store Connect API" angelegt werden (benötigt Account-Holder oder Admin-Rolle)

**Fehlende Dependencies mit Fallback:**
- Privates Zertifikats-Repo: wird im ersten Schritt von Wave 0 angelegt (5 Minuten, komplett auf GitHub)
- fastlane lokal: nicht nötig; läuft ausschließlich auf dem macOS-Runner in CI

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (bestehend seit Phase 2) |
| Config file | project.yml (FamilyScoreTests-Target) |
| Quick run command | `xcodebuild test-without-building -scheme FamilyScore -destination 'id=<UDID>'` |
| Full suite command | Über CI: `gh run list --limit 1` nach Push |

### Phase Requirements → Test Map

| Req ID | Verhalten | Test-Typ | Automatischer Command | Datei vorhanden? |
|--------|-----------|----------|-----------------------|-----------------|
| SETTINGS-01 | `CategoryService.toggleCategory()` ändert `is_enabled` korrekt | Unit (MockCategoryService) | `xcodebuild test ... -only-testing:FamilyScoreTests/CategoryServiceTests` | ❌ Wave 0 |
| SETTINGS-01 | `enabledCategories` filtert deaktivierte korrekt heraus | Unit | `... -only-testing:FamilyScoreTests/CategoryServiceTests/testEnabledFilter` | ❌ Wave 0 |
| SETTINGS-02 | `updateWeight()` aktualisiert `point_weight` ohne historische Einträge zu ändern | Unit (Mock) | `... -only-testing:FamilyScoreTests/CategoryServiceTests/testWeightUpdate` | ❌ Wave 0 |
| KID-02 | `KindDashboardView` zeigt keinen Familienvergleich | Unit/Snapshot (manuell) | Appetize.io (UI-Test) | ❌ Wave 0 |
| KID-03 | Nach `changeMemberRole(.child)` sieht User KindDashboardView | Integration (Appetize.io) | Appetize.io manuell | N/A |

### Sampling Rate

- **Pro Task-Commit:** Unit Tests via CI (`git push` → `gh run list`)
- **Pro Wave-Merge:** Full Suite grün in CI
- **Phase Gate:** CI grün + Appetize.io-Checkpoint: Kind-UI-Modus sichtbar + Settings-Toggles funktional

### Wave 0 Gaps

- [ ] `FamilyScoreTests/CategoryServiceTests.swift` — deckt SETTINGS-01, SETTINGS-02
- [ ] `FamilyScoreTests/Mocks/MockCategoryService.swift` — für Category-Tests
- [ ] `FamilyScore/Models/CategoryConfig.swift` — Decodable-Model für `category_config`

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Gilt | Standard-Control |
|---------------|------|-----------------|
| V2 Authentication | nein (Phase 2) | — |
| V3 Session Management | nein (Phase 2) | — |
| V4 Access Control | ja | RLS-Policy "Admin verwaltet Kategorien"; `change_member_role`-RPC (Phase 3) |
| V5 Input Validation | ja | `point_weight`: Bereichsvalidierung (> 0, <= 10) server- und clientseitig |
| V6 Cryptography | nein | — |

### Known Threat Patterns

| Muster | STRIDE | Standard-Mitigation |
|--------|--------|---------------------|
| Nicht-Admin ändert Kategorie-Konfiguration | Elevation of Privilege | RLS-Policy "Admin verwaltet Kategorien" (USING `is_family_admin()`) — Phase 1, bereits aktiv |
| Admin setzt `point_weight = 999` um Score zu manipulieren | Tampering | Serverseitige Bereichsvalidierung: `CHECK (point_weight > 0 AND point_weight <= 10)` in SQL-Constraint |
| Child-User navigiert direkt zu Settings-View via DeepLink | Elevation of Privilege | Settings-Tab nur wenn `role == .admin`; Admin-Actions in Views nur rendern wenn Rolle korrekt; RPC-Sicherheitsschicht dahinter |
| Hardcoded Secrets im Binary (Supabase Anon Key) | Information Disclosure | `Secrets.xcconfig` in `.gitignore`; bereits seit Phase 1 implementiert; bei Release-Build via CI-Secrets injiziert |
| App Store Connect API Key (.p8) in Git | Information Disclosure | Nur als GitHub Actions Secret (`ASC_KEY`); niemals in Repository commiten |

**Hinweis:** `point_weight`-DB-Constraint existiert noch nicht. Sollte als Teil der Phase-6-SQL-Migration hinzugefügt werden:
```sql
ALTER TABLE public.category_config
  ADD CONSTRAINT category_config_point_weight_range
  CHECK (point_weight > 0 AND point_weight <= 10);
```

---

## Sources

### Primary (HIGH confidence)
- `FamilyScore/supabase/migrations/20260515_initial_schema.sql` — `category_config`-Schema mit `is_enabled`, `point_weight`, Admin-RLS-Policy
- `FamilyScore/supabase/migrations/20260515_phase3_family_core.sql` — `change_member_role`-RPC, vollständig implementiert
- `FamilyScore/FamilyScore/Models/MemberRole.swift` — `MemberRole.child` bereits definiert
- `FamilyScore/FamilyScore/Services/FamilyService.swift` — Muster für neue Services (ObservableObject, Supabase-Queries, RPC-Calls)
- `.planning/research/ARCHITECTURE.md` — Points-Vorberechnung-Entscheidung (KRITISCH für SETTINGS-02)
- [fastlane docs — match](https://docs.fastlane.tools/actions/match/) — CITED
- [fastlane docs — App Store Connect API](https://docs.fastlane.tools/app-store-connect-api/) — CITED
- [Apple Developer Docs — Privacy Manifest Files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files) — CITED

### Secondary (MEDIUM confidence)
- [Bright Inventions — iOS TestFlight GitHub Actions Fastlane Match 2025](https://brightinventions.pl/blog/ios-testflight-github-actions-fastlane-match/) — konkrete GitHub-Actions-Struktur, cross-referenced mit fastlane-Docs
- [fastlane docs — GitHub Actions](https://docs.fastlane.tools/best-practices/continuous-integration/github/) — setup_ci, Gemfile, MATCH_PASSWORD
- [fastlane docs — upload_to_app_store](https://docs.fastlane.tools/actions/upload_to_app_store/) — App Store Submission

### Tertiary (LOW confidence)
- Diverse WebSearch-Ergebnisse zu SwiftUI role-based routing — allgemeines Pattern, keine spezifische Quelle nötig; Standard-EnvironmentObject-Ansatz

---

## Metadata

**Confidence-Aufschlüsselung:**
- Standard Stack: HIGH — alle Kernbibliotheken bereits im Projekt, nur Ergänzungen
- Kategorie-Konfiguration (SETTINGS-01/02): HIGH — Datenbankschema und RLS seit Phase 1 vorhanden
- Kind-UI (KID-02/03): HIGH — MemberRole und RPCs seit Phase 3 vorhanden; reine View-Arbeit
- App Store Submission (fastlane): MEDIUM — fastlane-Pattern gut dokumentiert, Ersteinrichtungsschritt auf Windows erfordert CI-Workaround
- Privacy Manifest: MEDIUM — Apple-Docs bestätigen Pflicht und Format; exakte Required-APIs für supabase-swift transitiv nicht ohne SDK-Inspektion vollständig verifizierbar

**Research-Datum:** 2026-05-17
**Gültig bis:** 2026-08-17 (90 Tage — stabiler Stack; fastlane-Versionsänderungen möglich)
