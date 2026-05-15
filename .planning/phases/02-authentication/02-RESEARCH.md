# Phase 2: Authentication — Research

**Researched:** 2026-05-15
**Domain:** Supabase Auth (email+password, Sign in with Apple) + SwiftUI Auth-State-Management + Session Persistence
**Confidence:** HIGH

---

## Summary

Phase 2 liefert den vollständigen Auth-Fluss: Registrierung mit E-Mail+Passwort, Sign in with Apple (nativ, ohne Edge Function), persistente Sessions über App-Neustarts hinweg, und Abmelden. Da Phase 1 bereits das `family_members`-Schema mit einem `handle_new_user`-Trigger aufgebaut hat, ist die Hauptaufgabe dieser Phase die iOS-seitige Umsetzung — AuthService, SwiftUI-Routing, nonce-basierter Apple-Login und die korrekte `authStateChanges`-Beobachtungsschleife.

Die kritische Erkenntnis: **Sign in with Apple braucht für die native iOS App keine Edge Function.** `signInWithIdToken(credentials: .init(provider: .apple, ...))` funktioniert vollständig client-seitig. Der Service-Role-Key wird nicht benötigt. Die CLAUDE.md-Notiz über eine Edge Function bezieht sich auf `auth.admin.inviteUserByEmail()` (Phase 3 Invite-Fluss) — nicht auf Sign in with Apple selbst.

Session-Persistenz ist in `supabase-swift` v2 **automatisch**: Das SDK speichert Tokens standardmäßig im iOS Keychain. Beim App-Start feuert das `authStateChanges`-Stream sofort ein `INITIAL_SESSION`-Event — die App muss nur diesen Stream beobachten, um den Persists-Status zu kennen.

**Primäre Empfehlung:** `AuthService` als `@Observable`-Klasse mit einer einzigen `authStateChanges`-Schleife implementieren. Keine manuelle Keychain-Verwaltung nötig. Sign in with Apple nativ mit `ASAuthorizationController` + nonce + `signInWithIdToken`. "No family"-State nach Registration als separater App-Zustand modellieren (`AppState.authenticated(hasFamily: Bool)`).

---

<phase_requirements>
## Phase Requirements

| ID | Beschreibung | Research-Grundlage |
|----|-------------|-------------------|
| AUTH-01 | User kann sich mit E-Mail + Passwort registrieren und einloggen | `supabase.auth.signUp()` / `signInWithPassword()` — beide direkt client-seitig |
| AUTH-02 | User kann sich mit Sign in with Apple registrieren und einloggen | `signInWithIdToken(provider: .apple, idToken:, nonce:)` — kein Backend nötig |
| AUTH-03 | User bleibt über App-Neustarts hinweg eingeloggt | Automatisch via Keychain-Persistenz; `INITIAL_SESSION`-Event prüft vorhandene Session |
| AUTH-04 | User kann sich ausloggen | `supabase.auth.signOut()` — Keychain wird automatisch geleert |
</phase_requirements>

---

## Project Constraints (from CLAUDE.md)

| Direktive | Auswirkung auf Phase 2 |
|-----------|----------------------|
| Supabase SDK NUR im Hauptapp-Target | AuthService lebt ausschließlich im App-Target |
| RLS immer aktivieren | `family_members`-Policies schon in Phase 1 aktiv; Auth-Token aktiviert sie |
| RLS nur mit echtem JWT testen | `signUp()` im Swift Client testen, nicht Dashboard |
| Secrets.xcconfig gitignored | Bereits in Phase 1 gelöst; Phase 2 fügt nichts hinzu |
| iOS 16.0 Minimum | `@Observable` nur auf iOS 17+; iOS 16 braucht `@StateObject`/`ObservableObject` |
| Swift 6, Xcode 16 | `@MainActor` auf ViewModels; `await MainActor.run {}` für UI-Updates |
| Apple Health/Fitness Ästhetik | Auth-Screens: minimalistisch, Dark Mode, keine bunten Form-Felder |
| 3 Taps Maximum | Registrierung/Login: maximal 3 Interaktionen bis zum Dashboard |
| Sign in with Apple via Edge Function für Service Role Key | Gilt NICHT für Auth-Signin; gilt für `inviteUserByEmail()` in Phase 3 |

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| E-Mail+Passwort Auth | API (Supabase Auth) | App Target (AuthService) | Server validiert Credentials, SDK verwaltet Tokens |
| Sign in with Apple Token Exchange | App Target (iOS native) | Supabase Auth Server | ASAuthorizationController im App-Target; kein Edge Function Layer |
| Session Persistence | iOS Keychain (automatisch) | App Target (nur Beobachter) | supabase-swift schreibt in Keychain; App liest via authStateChanges |
| Auth-State-Routing | App Target (SwiftUI) | — | RootView entscheidet zwischen Login/Onboarding/App basierend auf AppState |
| RLS-Aktivierung | Supabase DB (Phase 1 erledigt) | — | family_members-Policies aktiv; greifen sobald JWT vorhanden |
| "No Family"-Erkennung | App Target (AuthService) | Supabase DB (family_members) | Query auf family_members.family_id nach Login |
| Error Handling (Netzwerk, falsches PW) | App Target (AuthService) | — | Swift-Fehlertypen aus supabase-swift, lokalisierte Fehlermeldungen |

---

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| supabase-swift | 2.46.0 | Auth SDK: signUp, signIn, signOut, authStateChanges | Bereits in Phase 1 installiert; offizielles SDK |
| AuthenticationServices | iOS 13+ (Apple) | ASAuthorizationController für Sign in with Apple | Apple-Pflicht; keine Third-Party-Alternative |
| CryptoKit | iOS 13+ (Apple) | SHA256-Hash für Nonce | Apple-Framework; nötig für sicheren Nonce-Fluss |
| SwiftUI | iOS 16+ | Auth-Screens und State-basiertes Routing | Bereits Projektstandard |

### Supporting

| Library / Tool | Version | Purpose | When to Use |
|----------------|---------|---------|-------------|
| KeychainLocalStorage | Teil von supabase-swift | Custom Keychain service name (Bundle ID) | Empfohlen um macOS/iOS-Keychain-Prompt-Bug zu vermeiden |

**Installation:** Keine neuen Pakete — Phase 2 nutzt ausschließlich was Phase 1 installiert hat.

---

## Architecture Patterns

### System Architecture Diagram

```
iOS App Start
    │
    ▼
SupabaseClient init (Secrets.xcconfig → Info.plist)
    │
    ▼
AuthService.startObserving()
    ├─ authStateChanges AsyncStream
    │       │
    │       ├─ INITIAL_SESSION ──► session != nil? → AppState.authenticated
    │       │                       session == nil? → AppState.unauthenticated
    │       │
    │       ├─ SIGNED_IN ─────────► AppState.authenticated
    │       │                       → check family_members.family_id
    │       │                       → .hasFamily oder .noFamily
    │       │
    │       ├─ SIGNED_OUT ────────► AppState.unauthenticated (clear UI)
    │       │
    │       └─ TOKEN_REFRESHED ──► kein UI-Change nötig
    │
    ▼
RootView (switch on AppState)
    ├─ .unauthenticated → AuthFlowView
    │       ├─ WelcomeView (Login / Register Tabs)
    │       ├─ LoginView (E-Mail + PW + "Sign in with Apple" Button)
    │       └─ RegisterView (E-Mail + PW + Name)
    │
    ├─ .loading → SplashView / ProgressView
    │
    ├─ .authenticated(hasFamily: false) → OnboardingView
    │       └─ [Phase 3]: CreateFamily / JoinFamily
    │
    └─ .authenticated(hasFamily: true) → MainTabView
            └─ [Phase 4+]: Dashboard, Log, Settings

Auth Flows:
E-Mail+PW Register:  supabase.auth.signUp(email:password:)
                      → handle_new_user Trigger → family_members Row erstellt
E-Mail+PW Login:     supabase.auth.signInWithPassword(email:password:)
Sign in with Apple:  ASAuthorizationController → idToken + rawNonce
                      → supabase.auth.signInWithIdToken(provider:.apple, idToken:, nonce:)
Sign Out:            supabase.auth.signOut()
                      → Keychain automatisch geleert
                      → authStateChanges fires SIGNED_OUT
```

### Empfohlene Projektstruktur (Phase 2 Ergänzungen)

```
FamilyScore/
├── Services/
│   └── AuthService.swift          ← @Observable, authStateChanges Schleife
├── Models/
│   └── AppState.swift             ← enum AppState { loading, unauthenticated, authenticated(hasFamily: Bool) }
├── Views/
│   ├── RootView.swift             ← switch on AppState → View-Routing
│   └── Auth/
│       ├── AuthFlowView.swift     ← TabView: Login | Register
│       ├── LoginView.swift        ← E-Mail+PW Felder + Sign in with Apple Button
│       ├── RegisterView.swift     ← E-Mail+PW+Name Felder
│       └── SignInWithAppleView.swift  ← SignInWithAppleButton Wrapper + nonce-Logik
└── FamilyScoreApp.swift           ← AppContainer injiziert AuthService via .environment
```

### Pattern 1: AppState-Enum für Auth + Family-Status

**Was:** Ein `AppState`-Enum modelliert alle Routing-Zustände explizit.

**Warum:** Verhindert "authenticated aber noch kein Dashboard" Undefined State. Kein boolean-soup (`isLoggedIn && hasFamily && ...`).

```swift
// Source: Projektarchitektur-Entscheidung (ARCHITECTURE.md)
// AppState.swift — im App Target

enum AppState: Equatable {
    case loading                          // App startet, INITIAL_SESSION noch nicht angekommen
    case unauthenticated                  // Kein User, Login-Screen zeigen
    case authenticated(hasFamily: Bool)   // User eingeloggt, family_id vorhanden oder nicht
}
```

### Pattern 2: AuthService — @Observable mit authStateChanges

**Was:** Zentrale Klasse die `supabase.auth.authStateChanges` beobachtet und `AppState` aktualisiert.

**Wichtig:** Die `authStateChanges`-Schleife muss bei App-Start sofort starten (in `FamilyScoreApp.body` via `.task {}`). Das erste Event ist immer `INITIAL_SESSION` — mit oder ohne existierende Session. [VERIFIED: supabase.com/docs/reference/swift/auth-onauthstatechange]

```swift
// Source: Supabase Swift Tutorial (theswiftk.it.com) + offizielle Supabase Docs (adapted)
// Services/AuthService.swift

import Supabase
import Observation

@Observable
@MainActor
final class AuthService {
    private(set) var appState: AppState = .loading
    private(set) var currentUser: User? = nil
    
    // Fehler-State für UI-Feedback
    var authError: String? = nil
    
    func startObserving() async {
        for await (event, session) in await supabase.auth.authStateChanges {
            switch event {
            case .initialSession, .signedIn:
                if let session {
                    currentUser = session.user
                    let hasFamily = await checkFamilyMembership(userId: session.user.id)
                    appState = .authenticated(hasFamily: hasFamily)
                } else {
                    appState = .unauthenticated
                }
            case .signedOut:
                currentUser = nil
                appState = .unauthenticated
            case .tokenRefreshed:
                break  // Kein UI-State-Change nötig
            default:
                break
            }
        }
    }
    
    // MARK: - E-Mail + Passwort
    
    func signUp(email: String, password: String, displayName: String) async throws {
        authError = nil
        let session = try await supabase.auth.signUp(
            email: email,
            password: password,
            data: ["full_name": .string(displayName)]
        )
        // authStateChanges feuert SIGNED_IN — kein manueller State-Update nötig
        _ = session
    }
    
    func signIn(email: String, password: String) async throws {
        authError = nil
        try await supabase.auth.signInWithPassword(email: email, password: password)
        // authStateChanges feuert SIGNED_IN
    }
    
    func signOut() async throws {
        try await supabase.auth.signOut()
        // authStateChanges feuert SIGNED_OUT
    }
    
    // MARK: - Family-Check nach Login
    
    private func checkFamilyMembership(userId: UUID) async -> Bool {
        do {
            struct FamilyCheck: Decodable { let family_id: String? }
            let result: [FamilyCheck] = try await supabase
                .from("family_members")
                .select("family_id")
                .eq("id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value
            return result.first?.family_id != nil
        } catch {
            return false
        }
    }
}
```

**Hinweis für iOS 16 Compatibility:** `@Observable` ist iOS 17+. Für iOS 16 Support:

```swift
// iOS 16 kompatible Alternative:
final class AuthService: ObservableObject {
    @Published private(set) var appState: AppState = .loading
    // ...gleiche Logik, aber @Published statt @Observable
}

// In FamilyScoreApp.swift:
@StateObject private var authService = AuthService()
```

Da das Projekt iOS 16.0 als Minimum hat, muss `ObservableObject` + `@StateObject` verwendet werden, NICHT `@Observable` (iOS 17+). [VERIFIED: CLAUDE.md "iOS 16.0 Minimum"] [ASSUMED: supabase-swift v2.46.0 ist vollständig mit iOS 16 kompatibel — wurde nicht explizit geprüft]

### Pattern 3: Sign in with Apple — vollständiger Nonce-Fluss

**Was:** Native `ASAuthorizationController` + SHA256-Nonce + `signInWithIdToken`. Kein Edge Function Layer nötig.

**Warum kein Edge Function:** `signInWithIdToken(provider: .apple)` verarbeitet den Apple-Identity-Token direkt. Supabase validiert den Token gegen Apples JWKS. Der Service-Role-Key wird NICHT benötigt. [VERIFIED: supabase.com/docs/guides/auth/social-login/auth-apple "native apps do not need OAuth settings or backend processing"]

**Nonce-Fluss (Security-kritisch):**
1. App generiert `rawNonce` (kryptographisch zufällig)
2. App berechnet `sha256(rawNonce)` → sendet an Apple
3. Apple bäckt den SHA256-Hash in das `identityToken` ein
4. App sendet `rawNonce` (unhashed!) an `signInWithIdToken(nonce: rawNonce)`
5. Supabase re-hasht den rawNonce und vergleicht mit dem in Apple's Token eingebetteten Hash
6. Match = Token ist authentisch und wurde für diese spezifische Anfrage ausgestellt

```swift
// Source: Offizielles gotrue-swift Beispiel (github.com/supabase-community/gotrue-swift)
// + Apple Developer Docs (developer.apple.com/documentation/authenticationservices)
// Views/Auth/SignInWithAppleView.swift

import SwiftUI
import AuthenticationServices
import CryptoKit
import Supabase

struct SignInWithAppleView: View {
    @Environment(AuthService.self) private var authService
    
    // Nonce wird zwischen Request und Completion gespeichert
    @State private var currentNonce: String = ""
    
    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            let nonce = randomNonce()
            currentNonce = nonce
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256(nonce)   // SHA256-Hash an Apple senden
        } onCompletion: { result in
            Task {
                await handleAppleSignIn(result: result)
            }
        }
        .signInWithAppleButtonStyle(.white)
        .frame(height: 50)
    }
    
    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let auth):
            guard
                let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                let idTokenData = credential.identityToken,
                let idToken = String(data: idTokenData, encoding: .utf8)
            else {
                // Sollte nicht passieren — Apple-Credential hat immer identityToken
                return
            }
            
            do {
                // rawNonce (nicht den Hash!) übergeben — Supabase verifiziert intern
                try await supabase.auth.signInWithIdToken(
                    credentials: OpenIDConnectCredentials(
                        provider: .apple,
                        idToken: idToken,
                        nonce: currentNonce   // rawNonce, NICHT sha256(rawNonce)!
                    )
                )
                
                // Name nur beim ersten Login verfügbar — sofort speichern!
                if let fullName = credential.fullName,
                   let givenName = fullName.givenName {
                    let displayName = [givenName, fullName.familyName]
                        .compactMap { $0 }
                        .joined(separator: " ")
                    try? await supabase.auth.update(
                        user: UserAttributes(data: ["full_name": .string(displayName)])
                    )
                }
                // authStateChanges feuert SIGNED_IN → AuthService updated AppState
                
            } catch {
                // Fehler dem AuthService melden (z.B. Netzwerkfehler)
                authService.authError = localizeAuthError(error)
            }
            
        case .failure(let error as ASAuthorizationError) where error.code == .canceled:
            // User hat den Apple-Dialog abgebrochen — kein Fehler für UI
            break
            
        case .failure(let error):
            authService.authError = error.localizedDescription
        }
    }
    
    // MARK: - Nonce Helpers
    
    private func randomNonce(length: Int = 32) -> String {
        // Source: gotrue-swift offizielles Beispiel
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Nonce-Generierung fehlgeschlagen: SecRandomCopyBytes Fehler \(errorCode)")
        }
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }
    
    private func sha256(_ input: String) -> String {
        // Source: Apple CryptoKit Docs + gotrue-swift Beispiel
        let hashedData = SHA256.hash(data: Data(input.utf8))
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func localizeAuthError(_ error: Error) -> String {
        // Supabase Auth Fehler in nutzerfreundliche Meldungen übersetzen
        let msg = error.localizedDescription.lowercased()
        if msg.contains("invalid login") || msg.contains("invalid credentials") {
            return "E-Mail-Adresse oder Passwort falsch."
        } else if msg.contains("network") || msg.contains("connection") {
            return "Keine Internetverbindung. Bitte prüfe deine Verbindung."
        } else if msg.contains("already registered") || msg.contains("already exists") {
            return "Diese E-Mail-Adresse ist bereits registriert."
        }
        return "Ein Fehler ist aufgetreten. Bitte versuche es erneut."
    }
}
```

### Pattern 4: RootView — AppState-basiertes Routing

**Was:** Eine einzige Root-View liest `authService.appState` und rendert den passenden Screen.

```swift
// Source: Supabase Swift Tutorial (supabase.com/docs/guides/getting-started/tutorials/with-swift)
// + Projektarchitektur (ARCHITECTURE.md)
// Views/RootView.swift

import SwiftUI

struct RootView: View {
    @Environment(AuthService.self) private var authService
    
    var body: some View {
        Group {
            switch authService.appState {
            case .loading:
                // Splash-Screen während INITIAL_SESSION lädt
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                
            case .unauthenticated:
                AuthFlowView()
                
            case .authenticated(hasFamily: false):
                // User ist eingeloggt aber hat noch keine Familie
                // [Phase 3 liefert OnboardingView — Placeholder für Phase 2]
                OnboardingPlaceholderView()
                
            case .authenticated(hasFamily: true):
                // [Phase 4 liefert MainTabView — Placeholder für Phase 2]
                AuthenticatedPlaceholderView()
            }
        }
        .task {
            // authStateChanges Beobachtung startet beim ersten Erscheinen
            await authService.startObserving()
        }
    }
}
```

### Pattern 5: SupabaseClient mit explizitem KeychainLocalStorage

**Was:** `KeychainLocalStorage` mit Bundle ID als Service-Name konfigurieren — vermeidet den "supabase.gotrue.swift"-Keychain-Prompt-Bug auf macOS und ist Best Practice. [VERIFIED: github.com/orgs/supabase/discussions/28132]

```swift
// Source: Supabase GitHub Discussion #28132 + Swift Package Index Docs
// Supabase.swift (bereits in Phase 1, hier ergänzt)

import Supabase

let supabase = SupabaseClient(
    supabaseURL: URL(string: Bundle.main.object(
        forInfoDictionaryKey: "SUPABASE_URL") as! String)!,
    supabaseKey: Bundle.main.object(
        forInfoDictionaryKey: "SUPABASE_KEY") as! String,
    options: SupabaseClientOptions(
        auth: SupabaseClientOptions.AuthOptions(
            storage: KeychainLocalStorage(service: "com.familyscore")
            // Expliziter Service-Name verhindert Keychain-Prompt-Bug
        )
    )
)
```

### Anti-Patterns vermeiden

- **Anti-Pattern: Manuelle Token-Persistenz** — Tokens selbst in `UserDefaults` oder `Keychain` schreiben. `supabase-swift` erledigt das automatisch. Nur `authStateChanges` beobachten.
- **Anti-Pattern: `if supabase.auth.currentSession != nil` beim App-Start** — Race Condition; `INITIAL_SESSION` aus `authStateChanges` ist die einzige zuverlässige Methode.
- **Anti-Pattern: Apple-Name nicht beim ersten Login speichern** — Apple sendet `fullName` NUR beim allerersten Login. Danach ist `credential.fullName` nil. Sofort in `supabase.auth.update(user:)` schreiben.
- **Anti-Pattern: Nonce-Fehler (sha256 statt rawNonce an Supabase)** — `signInWithIdToken(nonce:)` erwartet den `rawNonce`, nicht den Hash. Apple bekommt den Hash, Supabase bekommt den rawNonce.
- **Anti-Pattern: Apple-Abbruch als Fehler behandeln** — `ASAuthorizationError.canceled` ist kein Fehler; User hat bewusst abgebrochen. Kein Error-Banner zeigen.

---

## Don't Hand-Roll

| Problem | Nicht bauen | Stattdessen | Warum |
|---------|-------------|-------------|-------|
| Session-Persistenz | Eigene Keychain-Wrapper für Tokens | `supabase-swift` automatisch via `KeychainLocalStorage` | Refresh-Token-Rotation, Expiry-Handling, Thread-Safety — alles eingebaut |
| Token-Refresh | Eigene Refresh-Logik mit Timer | `supabase-swift` refresht automatisch vor Expiry | Refresh-Token-Reuse-Protection (Issue #486) ist komplex |
| Auth-State-Management | Eigene `NotificationCenter`-Events | `authStateChanges` AsyncStream | Typ-sicher, async/await-nativ, deckt alle Events inkl. Hintergrund-Refresh |
| Apple-Identity-Token-Validierung | Eigenes JWT-Parsing gegen Apple JWKS | `signInWithIdToken(provider: .apple)` | Supabase validiert gegen Apple JWKS; Fehler bei selbst implementierter Validierung haben Sicherheitsfolgen |
| Passwort-Hashing | Eigene bcrypt-Implementierung | Supabase Auth Backend | Auth läuft server-seitig; Client sendet nur Plaintext über TLS |
| E-Mail-Validierung | Regex-Prüfung im Client | Minimale Format-Prüfung + Supabase Validation | Supabase gibt `422 Unprocessable Entity` zurück; Client zeigt Fehler aus Response |

---

## RLS-Implikationen für Phase 2

Phase 1 hat alle Tabellen mit RLS ausgestattet. Phase 2 muss keine neuen Policies schreiben — der erste Login aktiviert die bestehenden Policies automatisch durch den JWT im `Authorization`-Header.

**Was passiert beim ersten `signUp()`:**
1. Supabase erstellt `auth.users`-Eintrag
2. `handle_new_user()`-Trigger erstellt `family_members`-Row mit `family_id = NULL`
3. `SIGNED_IN`-Event → `authStateChanges` → `AuthService` updated AppState
4. `checkFamilyMembership()` → Query auf `family_members.family_id` → `NULL` → `AppState.authenticated(hasFamily: false)`

**"No Family"-RLS-Edge-Case:** Ein frisch registrierter User hat `family_id = NULL`. Die RLS-Policy auf `families` (`is_family_member(id)`) gibt `false` zurück für alle Families. Das ist korrekt: User sieht keine Families. Die `family_members`-Policy erlaubt dem User das eigene Profil zu lesen (`id = auth.uid()`). [VERIFIED: 01-RESEARCH.md RLS-Policies]

**Keine neuen Policies nötig** — Phase 1 hat bereits alle erforderlichen angelegt.

---

## Common Pitfalls

### Pitfall 1: Apple fullName nur beim ersten Login verfügbar

**What goes wrong:** `credential.fullName?.givenName` ist beim zweiten Login `nil`. Der User hat keinen Anzeigenamen in `family_members.display_name`.
**Why it happens:** Apple Design-Entscheidung: Nutzerdaten werden nur beim ersten Consent gesendet.
**How to avoid:** Direkt nach erfolgreichem `signInWithIdToken` in `supabase.auth.update(user: UserAttributes(data: ["full_name": ...]))` schreiben. `handle_new_user()`-Trigger liest `new.raw_user_meta_data->>'full_name'`.
**Warning signs:** User erscheint als "New Member" statt mit richtigem Namen.

### Pitfall 2: authStateChanges nicht früh genug gestartet

**What goes wrong:** `startObserving()` wird erst aufgerufen wenn ein bestimmter Screen erscheint. Das `INITIAL_SESSION`-Event (erstes Event beim App-Start) wird verpasst. App hängt im `.loading`-State.
**Why it happens:** Asynchrone Initialisierung — der erste Event kommt unmittelbar nach Client-Init.
**How to avoid:** `Task { await authService.startObserving() }` in `FamilyScoreApp.body` via `.task {}` modifier auf der root-level View, NICHT in einem untergeordneten Screen.
**Warning signs:** App bleibt auf Splash-Screen; kein Routing passiert.

### Pitfall 3: Nonce-Verwechslung (rawNonce vs. sha256(nonce))

**What goes wrong:** `signInWithIdToken(nonce: sha256(currentNonce))` statt `signInWithIdToken(nonce: currentNonce)`. Supabase re-hasht den empfangenen Wert und vergleicht mit dem in Apple's Token eingebetteten SHA256-Hash — wenn schon gehasht übergeben, schlägt der Vergleich fehl: `400 Bad Request`.
**How to avoid:** Apple bekommt `sha256(rawNonce)`. Supabase bekommt `rawNonce`. Kommentar im Code explizit.
**Warning signs:** Sign in with Apple scheitert mit `400` oder `"nonce mismatch"` Error.

### Pitfall 4: Refresh Token Silent Logout (bekannter supabase-swift Bug)

**What goes wrong:** Nach 2-3 Tagen werden User unerwartet ausgeloggt. `authStateChanges` feuert `SIGNED_OUT`. App zeigt Login-Screen ohne User-Aktion.
**Why it happens:** Refresh-Token-Reuse-Protection greift wenn zwei simultane Refresh-Versuche stattfinden (z.B. Foreground/Background-Wechsel). [VERIFIED: PITFALLS.md, GitHub Issue #486]
**How to avoid:** `authStateChanges` auf `SIGNED_OUT` hören und zur Login-View routen. User sieht Fehlermeldung "Session abgelaufen, bitte neu einloggen." Kein Crash, kein Datenverlust.
**Warning signs:** TestFlight-Tester berichten nach 2-3 Tagen über unerklärten Logout.

### Pitfall 5: Apple-Cancel als Fehler behandeln

**What goes wrong:** User tippt auf "Sign in with Apple", entscheidet sich um, tippt "Abbrechen". App zeigt Error-Banner "Ein Fehler ist aufgetreten."
**Why it happens:** `ASAuthorizationError.canceled` landet im `.failure`-Case des Result.
**How to avoid:** Im `handleAppleSignIn`-Handler: `case .failure(let error as ASAuthorizationError) where error.code == .canceled: break` — kein Error-State setzen.

### Pitfall 6: RLS-Test nur im Dashboard (bypassed)

**What goes wrong:** Developer testet `signUp()` via Supabase Dashboard SQL-Editor. RLS-Policies greifen nicht → falsches Ergebnis. Echte App-User sehen andere Daten.
**How to avoid:** Alle Auth-Tests via Swift Client auf echtem Gerät oder Simulator mit echtem JWT. [VERIFIED: CLAUDE.md + PITFALLS.md]

---

## Code Examples

### E-Mail+PW Registrierung

```swift
// Source: supabase.com/docs/reference/swift/auth-signup
try await supabase.auth.signUp(
    email: "user@example.com",
    password: "sicheres-passwort-123",
    data: ["full_name": .string("Max Mustermann")]
)
// handle_new_user-Trigger erstellt family_members Row automatisch
```

### E-Mail+PW Login

```swift
// Source: supabase.com/docs/reference/swift/auth-signinwithpassword
try await supabase.auth.signInWithPassword(
    email: "user@example.com",
    password: "sicheres-passwort-123"
)
```

### Abmelden

```swift
// Source: supabase.com/docs/reference/swift/auth-signout
try await supabase.auth.signOut()
// Keychain wird automatisch geleert
// authStateChanges feuert SIGNED_OUT
```

### Auth-State beobachten (vollständig)

```swift
// Source: supabase.com/docs/guides/getting-started/tutorials/with-swift (adaptiert)
for await (event, session) in await supabase.auth.authStateChanges {
    if [.initialSession, .signedIn, .signedOut].contains(event) {
        isAuthenticated = session != nil
    }
}
```

---

## State of the Art

| Alte Methode | Aktuelle Methode | Geändert seit | Bedeutung |
|--------------|-----------------|--------------|-----------|
| `supabase.auth.onAuthStateChange { }` (Closure) | `supabase.auth.authStateChanges` (AsyncStream) | supabase-swift v2.x | AsyncStream ist Swift-Concurrency-nativ; Closure-Variante funktioniert noch |
| `@ObservedObject` + `ObservableObject` | `ObservableObject` + `@StateObject` (iOS 16) / `@Observable` (iOS 17) | iOS 17 / Swift 5.9 | iOS 16-Minimum erzwingt `@StateObject`; `@Observable` erst ab Phase 4+ wenn iOS 17 Minimum |
| `supabase.auth.session` synchron lesen beim Start | `INITIAL_SESSION`-Event aus `authStateChanges` warten | supabase-swift v2.x | Synchrones Lesen ist Race-Condition-anfällig; AsyncStream ist die empfohlene Methode |
| `anon`-Keys | `sb_publishable_xxx`-Keys | 2025 (Supabase) | Legacy bis Ende 2026; Phase 1 schon auf neue Keys |

---

## Validation Architecture

> `nyquist_validation: true` in config.json — diese Sektion ist Pflicht.

### Test-Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (wird in Phase 2 Wave 0 aufgesetzt — Phase 1 hatte noch kein XCTest-Target) |
| Config file | `FamilyScore.xcodeproj` → neues Test-Target `FamilyScoreTests` |
| Quick run command | `xcodebuild test -scheme FamilyScore -destination "platform=iOS Simulator,name=iPhone 16"` |
| Full suite command | Wie Quick run + echtes Gerät für AUTH-03 (Keychain-Persistenz) |

### Requirements → Test-Map

| Req ID | Verhalten | Test-Typ | Automatisierbar | Datei |
|--------|-----------|----------|-----------------|-------|
| AUTH-01 | signUp() erstellt User + family_members Row | Integration (Simulator) | Ja | `FamilyScoreTests/AuthServiceTests.swift` |
| AUTH-01 | signInWithPassword() mit falschen Credentials → Fehler | Unit | Ja | `FamilyScoreTests/AuthServiceTests.swift` |
| AUTH-01 | signInWithPassword() mit richtigen Credentials → Session | Integration | Ja | `FamilyScoreTests/AuthServiceTests.swift` |
| AUTH-02 | signInWithIdToken Apple → kein Edge Function nötig | Manuell (Apple-Auth braucht echtes Gerät + Apple ID) | Nein | Manuell |
| AUTH-02 | Nonce-Mismatch → Fehler-Handling | Unit (Mock) | Ja | `FamilyScoreTests/AuthServiceTests.swift` |
| AUTH-03 | App kill + restart → INITIAL_SESSION mit Session | Integration auf echtem Gerät | Teilweise (Gerät nötig) | Manuell |
| AUTH-04 | signOut() → authStateChanges feuert SIGNED_OUT | Integration | Ja | `FamilyScoreTests/AuthServiceTests.swift` |
| AUTH-04 | Nach signOut() → Keychain leer, kein re-login | Integration | Ja | `FamilyScoreTests/AuthServiceTests.swift` |

### Wave 0 Gaps

- [ ] `FamilyScoreTests/` — XCTest-Target erstellen (war Phase 1 Defer)
- [ ] `FamilyScoreTests/AuthServiceTests.swift` — Unit + Integration Tests für AUTH-01, AUTH-04
- [ ] `FamilyScoreTests/Mocks/MockAuthService.swift` — Mock für Preview-Injektion
- [ ] Framework install: `xcodebuild -scheme FamilyScore test` — schlägt fehl bis Test-Target existiert

### Sampling Rate

- **Per Task Commit:** `xcodebuild build -scheme FamilyScore` (Build muss grün bleiben)
- **Per Wave Merge:** `xcodebuild test -scheme FamilyScoreTests` (Test-Suite grün)
- **Phase Gate:** Alle 4 Requirements manuell auf Gerät verifiziert vor `/gsd-verify-work`

---

## Environment Availability

> Phase 2 hat keine neuen externen Abhängigkeiten — Supabase-Projekt und Xcode sind seit Phase 1 verfügbar.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Supabase-Projekt (live) | AUTH-01, AUTH-02, AUTH-03, AUTH-04 | Ja (Phase 1 aufgebaut) | Free Tier | — |
| Xcode 16+ auf Mac | Build + Test | Ja (Phase 1 Voraussetzung) | 16+ | Kein Fallback |
| iOS Gerät (physisch) | AUTH-02 (Apple Sign in), AUTH-03 (Keychain) | Bereitstellen | iOS 16+ | Simulator für AUTH-01, AUTH-04 |
| Apple Developer Account | AUTH-02 (Sign in with Apple Capability) | Ja (Phase 1 Voraussetzung) | — | — |
| CryptoKit | AUTH-02 (SHA256 Nonce) | Ja (Apple Framework, iOS 13+) | — | — |
| AuthenticationServices | AUTH-02 (ASAuthorizationController) | Ja (Apple Framework, iOS 13+) | — | — |

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | Ja | supabase-swift Auth (PKCE default), Sign in with Apple via Apple |
| V2.1 Password Security | Ja | Supabase erzwingt Mindest-Passwortlänge (6 Zeichen Standard) — serverseitig |
| V2.7 OOB Authentication (Apple) | Ja | ASAuthorizationController + nonce; kein Service-Role-Key im Client |
| V3 Session Management | Ja | Keychain-Persistenz (automatisch); Token-Rotation via supabase-swift |
| V4 Access Control | Ja (geerbt) | RLS-Policies aus Phase 1 aktiv sobald JWT vorhanden |
| V5 Input Validation | Teilweise | Client: E-Mail-Format-Check; Server: Supabase-Validation |
| V6 Cryptography | Ja | Nonce: `SecRandomCopyBytes` + `CryptoKit.SHA256`; niemals manuell |

### Known Threat Patterns für diesen Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Replay-Angriff auf Apple-Identity-Token | Spoofing | SHA256-Nonce: eindeutig pro Request, einmalig verwendbar |
| Session-Hijacking via Keychain-Exfiltration | Information Disclosure | iOS Keychain mit `kSecAttrAccessibleAfterFirstUnlock`; App-Sandbox |
| Refresh-Token-Reuse (Bug #486) | DoS (unbeabsichtigt) | `authStateChanges` SIGNED_OUT abfangen → Login-Screen zeigen |
| Service-Role-Key im Client-Binary | Elevation of Privilege | Nicht nötig für Sign in with Apple; nur bei `inviteUserByEmail()` (Phase 3: Edge Function) |
| Passwort im Plain-Text im Client gespeichert | Information Disclosure | Never store — nur temporär in SwiftUI `@State`-Variable während Input |
| Cross-Family-RLS-Bypass | Information Disclosure | RLS aus Phase 1 greifen; JWT enthält `auth.uid()`, kein Family-ID im Token nötig |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `supabase-swift` v2.46.0 ist vollständig iOS 16 kompatibel (API-Ebene `authStateChanges`, `signUp`, `signInWithIdToken`) | Standard Stack | Niedrig: SDK hat iOS 13+ als Minimum laut SPM Package; unwahrscheinlich dass iOS 16 Inkompatibilität besteht |
| A2 | `AuthService.startObserving()` via `.task {}` in RootView feuert `INITIAL_SESSION` zuverlässig vor der ersten UI-Render-Entscheidung | Pattern 2 | Mittel: Race Condition möglich; Workaround: `.loading`-State anzeigen bis erstes Event ankommt (bereits eingebaut) |
| A3 | `handle_new_user`-Trigger aus Phase 1 läuft zuverlässig nach `signUp()` und erstellt `family_members`-Row | RLS-Implikationen | Mittel: Falls Trigger fehlschlägt (z.B. DB-Verbindungsproblem), existiert kein `family_members`-Eintrag; `checkFamilyMembership()` gibt `false` zurück → User landet in `OnboardingPlaceholder` statt einem Fehler. Akzeptabel als Fallback. |
| A4 | Sign in with Apple benötigt keine App-Side-Konfiguration im Apple Developer Portal außer `Sign in with Apple`-Capability im App Target | Architecture | Hoch: Falls Supabase-Projekt in der Apple Developer Console als Service registriert werden muss, ist ein Setup-Schritt nötig. Laut offizieller Docs ("native apps do not need OAuth settings") ist dies nicht erforderlich. |
| A5 | `KeychainLocalStorage(service: "com.familyscore")` ist in supabase-swift v2.46.0 verfügbar (nicht eine ältere API) | Pattern 5 | Niedrig: API existiert laut swiftpackageindex.com Docs für v2.37.0+; v2.46.0 wird es enthalten |

---

## Open Questions

1. **Sign in with Apple: Apple Developer Console Service-Registrierung**
   - Was wir wissen: Laut offizieller Supabase Docs braucht die native iOS App keine OAuth-Konfiguration
   - Was unklar ist: Ob das spezifische Supabase-Projekt (aus Phase 1) in der Apple Developer Console als "Service" registriert werden muss
   - Empfehlung: Beim ersten Test prüfen; falls `signInWithIdToken` einen `provider_token`-Fehler wirft, im Apple Developer Portal nachsehen

2. **`family_members`-Trigger und "New Member" Name bei E-Mail-Registrierung**
   - Was wir wissen: Trigger liest `new.raw_user_meta_data->>'full_name'`
   - Was unklar ist: Ob `supabase.auth.signUp(data: ["full_name": .string(...)])` diesen Wert korrekt in `raw_user_meta_data` setzt
   - Empfehlung: Im ersten Integrationstest prüfen; Fallback: `family_members.display_name` via separatem UPDATE nach signUp setzen

3. **iOS 16 vs. iOS 17 ObservableObject Pattern**
   - Was wir wissen: `@Observable` ist iOS 17+; Projekt hat iOS 16.0 als Minimum
   - Was unklar ist: Ob ein `@Observable`-Wrapper mit `@available(iOS 17, *)` parallel zu `ObservableObject` sinnvoll ist
   - Empfehlung: Für Phase 2 ausschließlich `ObservableObject` + `@StateObject` verwenden. Migration zu `@Observable` ist ein optionaler Refactor in Phase 6.

---

## Sources

### Primary (HIGH confidence)
- [Supabase Swift Auth Reference — signInWithIdToken](https://supabase.com/docs/reference/swift/auth-signinwithidtoken) — API-Signatur verifiziert
- [Supabase Swift Auth Reference — onAuthStateChange](https://supabase.com/docs/reference/swift/auth-onauthstatechange) — AsyncStream Pattern verifiziert
- [Supabase Docs — Sign in with Apple (Native)](https://supabase.com/docs/guides/auth/social-login/auth-apple) — "native apps do not need OAuth settings" verifiziert
- [Supabase Swift Tutorial — with-swift](https://supabase.com/docs/guides/getting-started/tutorials/with-swift) — INITIAL_SESSION Pattern verifiziert
- [gotrue-swift Beispiel — SignInWithAppleView.swift](https://github.com/supabase-community/gotrue-swift/blob/main/Examples/Shared/Sources/SignInWithAppleView.swift) — offizielles Nonce-Implementierungsbeispiel
- Phase 1 RESEARCH.md (01-RESEARCH.md) — RLS-Policies, handle_new_user-Trigger, AppContainer-Pattern
- ARCHITECTURE.md (Projektrecherche) — MVVM + Service Layer + Component Boundaries
- PITFALLS.md (Projektrecherche) — Refresh Token Bug #486, Realtime Lifecycle, RLS pitfalls

### Secondary (MEDIUM confidence)
- [Supabase Discussion #28132 — Keychain access on startup](https://github.com/orgs/supabase/discussions/28132) — KeychainLocalStorage custom service name Workaround
- [SwiftPackageIndex — KeychainLocalStorage](https://swiftpackageindex.com/supabase/supabase-swift/v2.37.0/documentation/supabase/keychainlocalstorage) — Klasse und API verifiziert
- [The Swift Kit — Supabase SwiftUI Tutorial 2025](https://theswiftk.it.com/blog/supabase-swiftui-tutorial) — Nonce-Generierung und Apple Sign-In Flow
- [Supabase Discussion #35158 — Session persistence](https://github.com/orgs/supabase/discussions/35158) — Keychain als default Storage bestätigt

### Tertiary (LOW confidence)
- WebSearch-Ergebnisse zu AuthState Enum Patterns — aus Community-Tutorials, nicht offizieller Quelle; Pattern-Code selbst basiert auf verifizierten offiziellen Quellen

---

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH — supabase-swift API aus offiziellen Docs; Apple Frameworks aus Apple Docs
- Auth-Flow (E-Mail+PW): HIGH — offiziell dokumentiert, einfache API
- Sign in with Apple Flow: HIGH — offizielles gotrue-swift Beispiel + Supabase Docs bestätigen kein Edge Function Layer
- Session Persistence: HIGH — Keychain-Default durch mehrere Quellen (Docs + Community Discussions) bestätigt
- AppState-Enum-Pattern: MEDIUM — aus Community-Pattern; keine offizielle "AuthState"-Definition in Supabase Docs
- iOS 16 vs. @Observable: HIGH — Apple Docs klar: @Observable ist iOS 17+
- RLS-Implikationen: HIGH — direkt aus Phase 1 RESEARCH.md und ARCHITECTURE.md

**Research date:** 2026-05-15
**Valid until:** 2026-06-15 (30 Tage; supabase-swift Auth API ist stabil; Sign in with Apple Anforderungen ändern sich selten)
