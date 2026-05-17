# Phase 3: Family Core — Pattern Map

**Mapped:** 2026-05-15
**Files analyzed:** 16 (neu/geaendert)
**Analogs found:** 14 / 16

---

## File Classification

| Neue/geaenderte Datei | Rolle | Data Flow | Naechster Analog | Match-Qualitaet |
|----------------------|-------|-----------|-----------------|-----------------|
| `supabase/migrations/20260515_phase3_family_core.sql` | migration | CRUD | `supabase/migrations/20260515_initial_schema.sql` | exact |
| `FamilyScore/Services/FamilyService.swift` | service | CRUD + request-response | `FamilyScore/Services/AuthService.swift` (Plan 02-02) | exact |
| `FamilyScore/Models/FamilyMember.swift` | model | — | `FamilyScoreKit/Sources/FamilyScoreKit/WidgetData.swift` (MemberScore) | role-match |
| `FamilyScore/Models/Family.swift` | model | — | `FamilyScoreKit/Sources/FamilyScoreKit/WidgetData.swift` | role-match |
| `FamilyScore/Models/FamilyInvite.swift` | model | — | `FamilyScoreKit/Sources/FamilyScoreKit/WidgetData.swift` | role-match |
| `FamilyScore/Models/ChildProfile.swift` | model | — | `FamilyScoreKit/Sources/FamilyScoreKit/WidgetData.swift` | role-match |
| `FamilyScore/Views/Family/FamilyOnboardingView.swift` | component | request-response | `FamilyScore/Views/Auth/AuthFlowView.swift` (Plan 02-02) | exact |
| `FamilyScore/Views/Family/CreateFamilyView.swift` | component | request-response | `FamilyScore/Views/Auth/RegisterView.swift` (Plan 02-02) | exact |
| `FamilyScore/Views/Family/JoinFamilyView.swift` | component | request-response | `FamilyScore/Views/Auth/LoginView.swift` (Plan 02-02) | exact |
| `FamilyScore/Views/Family/MemberListView.swift` | component | CRUD | `FamilyScore/Views/Auth/AuthFlowView.swift` (Plan 02-02) | role-match |
| `FamilyScore/Views/Family/InviteSheet.swift` | component | request-response | `FamilyScore/Views/Auth/LoginView.swift` (Plan 02-02) | role-match |
| `FamilyScore/Views/Family/RolePickerSheet.swift` | component | CRUD | `FamilyScore/Views/Auth/LoginView.swift` (Plan 02-02) | role-match |
| `FamilyScore/Views/Family/AddChildView.swift` | component | CRUD | `FamilyScore/Views/Auth/RegisterView.swift` (Plan 02-02) | exact |
| `FamilyScore/Views/RootView.swift` | component | request-response | `FamilyScore/Views/RootView.swift` (Plan 02-02) | exact (modify) |
| `FamilyScore/Services/AuthService.swift` | service | event-driven | `FamilyScore/Services/AuthService.swift` (Plan 02-02) | exact (modify) |
| `FamilyScoreTests/Mocks/MockFamilyService.swift` | test | — | `FamilyScoreTests/Mocks/MockAuthService.swift` (Plan 02-01) | exact |

---

## Pattern Assignments

### `supabase/migrations/20260515_phase3_family_core.sql` (migration, CRUD)

**Analog:** `FamilyScore/supabase/migrations/20260515_initial_schema.sql`

**Datei-Header-Pattern** (Zeilen 1-7):
```sql
-- =============================================================================
-- Family Score: Phase 3 Family Core
-- Phase 3 Foundation — Family Creation, Invite Flow, Child Profiles
-- =============================================================================

-- Enable required extensions (bereits aktiv aus Phase 1)
-- create extension if not exists "pgcrypto"; -- NICHT erneut ausfuehren
```

**Tabellen-DDL-Pattern** (Zeilen 11-31, Analog aus initial_schema.sql):
```sql
-- Muster: Tabelle mit uuid PK, family_id FK, timestamptz created_at/updated_at
create table public.child_profiles (
  id            uuid primary key default gen_random_uuid(),
  family_id     uuid not null references public.families(id) on delete cascade,
  display_name  text not null,
  avatar_color  text not null default '#FF9500',
  created_by    uuid not null references auth.users(id) on delete cascade,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index child_profiles_family_id on public.child_profiles(family_id);
```

**SECURITY DEFINER Funktion-Pattern** (Zeilen 33-59, Analog: `handle_new_user` und `is_family_member`):
```sql
-- Muster fuer alle RPCs in Phase 3:
-- 1. security definer + set search_path = '' (Pflicht gegen Injection)
-- 2. Sicherheitscheck zuerst (IF NOT / IF EXISTS + RAISE EXCEPTION)
-- 3. Atomare Datenaenderungen (kein BEGIN/COMMIT noetig — PostgREST wrapped automatisch)
-- 4. RETURNS uuid oder void

create or replace function public.create_family(family_name text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_family_id uuid;
begin
  -- Sicherheitscheck: User darf noch keiner Familie angehoeren
  if exists (
    select 1 from public.family_members
    where id = (select auth.uid())
      and family_id is not null
  ) then
    raise exception 'User gehoert bereits einer Familie an';
  end if;
  -- ... (atomare Datenaenderungen)
  return v_family_id;
end;
$$;
```

**RLS-Policy-Pattern** (Zeilen 248-280, Analog aus initial_schema.sql):
```sql
-- Muster: alter table ... enable row level security; dann Policies
-- is_family_member() und is_family_admin() sind bereits aus Phase 1 vorhanden

alter table public.child_profiles enable row level security;

create policy "Familienmitglieder sehen Kind-Profile"
  on public.child_profiles for select to authenticated
  using (public.is_family_member(family_id));

create policy "Admin verwaltet Kind-Profile"
  on public.child_profiles for all to authenticated
  using (public.is_family_admin(family_id));

create policy "Admin erstellt Kind-Profile"
  on public.child_profiles for insert to authenticated
  with check (public.is_family_admin(family_id));
```

**Policy-DROP-Pattern** (fuer Aenderung bestehender Policies aus Phase 1):
```sql
-- Muster: Existierende Policy explizit droppen, dann neue erstellen
drop policy if exists "User verwaltet eigenes Profil" on public.family_members;

create policy "User aktualisiert eigenes Profil (kein Rollen-Selbst-Upgrade)"
  on public.family_members for update to authenticated
  using ((select auth.uid()) = id)
  with check (...);
```

---

### `FamilyScore/Services/FamilyService.swift` (service, CRUD + request-response)

**Analog:** `FamilyScore/Services/AuthService.swift` (aus Plan 02-02)

**Imports-Pattern** (Analog: AuthService.swift Zeilen 1-3):
```swift
// FamilyScore/Services/FamilyService.swift
// Target Membership: FamilyScore (App) ONLY
// iOS 16.0 Minimum: ObservableObject + @Published (NICHT @Observable — iOS 17+)

import Foundation
import Supabase
```

**ObservableObject-Klassen-Pattern** (Analog: AuthService.swift):
```swift
@MainActor
final class FamilyService: ObservableObject {

    @Published private(set) var currentFamily: Family?
    @Published private(set) var members: [FamilyMember] = []
    @Published private(set) var childProfiles: [ChildProfile] = []
    @Published var serviceError: String? = nil
```

**Kern-Fetch-Pattern** (Analog: `checkFamilyMembership` in AuthService.swift):
```swift
// Muster: async func, do/catch, Supabase-Chain, @Published setzen
func fetchMembers(familyId: UUID) async {
    do {
        let fetched: [FamilyMember] = try await supabase
            .from("family_members")
            .select()
            .eq("family_id", value: familyId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value
        members = fetched
    } catch {
        serviceError = "Mitglieder konnten nicht geladen werden."
    }
}
```

**RPC-Aufruf-Pattern** (Kein exakter Analog im Codebase — aus RESEARCH.md Pattern 1/2):
```swift
// Muster fuer alle RPC-Aufrufe:
// 1. Nested struct fuer Params (Encodable + CodingKeys fuer snake_case)
// 2. supabase.rpc(name, params:).execute().value
// 3. throws (kein do/catch hier — Aufrufer faengt ab)

func createFamily(name: String) async throws -> UUID {
    struct Params: Encodable {
        let familyName: String
        enum CodingKeys: String, CodingKey { case familyName = "family_name" }
    }
    return try await supabase
        .rpc("create_family", params: Params(familyName: name))
        .execute()
        .value
}
```

**Error-Enum-Pattern** (Analog: `authError: String?` in AuthService.swift — Phase 3 verwendet typisierte Errors):
```swift
enum FamilyServiceError: Error, LocalizedError {
    case notAuthenticated
    case familyNotFound
    case invalidToken
    case alreadyInFamily
    case insufficientPermissions

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Bitte zuerst einloggen."
        case .invalidToken: return "Ungültiger oder abgelaufener Einladungscode."
        // ...
        }
    }
}
```

**Supabase-Insert-mit-Returning-Pattern** (fuer generateInvite):
```swift
// Muster: insert + select(Spaltenname) + single() + .value
// Gibt nur die angeforderten Spalten zurueck (effizienter als select(*))

struct InviteResponse: Decodable { let token: String }

let response: InviteResponse = try await supabase
    .from("family_invites")
    .insert(NewInvite(...))
    .select("token")
    .single()
    .execute()
    .value
```

---

### `FamilyScore/Models/FamilyMember.swift` (model)

**Analog:** `FamilyScoreKit/Sources/FamilyScoreKit/WidgetData.swift` (MemberScore-Struct)

**Codable-Struct-Pattern** (Analog: WidgetData.swift Zeilen 7-19):
```swift
// Muster: public struct mit Codable, Identifiable, let-Properties
// snake_case Spaltenname = swift camelCase Property-Name → CodingKeys noetig wenn unterschiedlich
// Fuer Supabase-Decoding: Feldnamen muessen DB-Spaltennamen entsprechen (snake_case)

struct FamilyMember: Codable, Identifiable {
    let id: UUID
    let family_id: UUID?       // snake_case = DB-Spaltenname direkt (kein CodingKey noetig)
    let display_name: String
    let avatar_color: String
    let role: String           // oder: MemberRole (wenn enum Codable)
    let created_at: Date
}
```

**Hinweis:** `WidgetData.MemberScore` verwendet camelCase mit explizitem `init` — Supabase-Decoding braucht snake_case Property-Namen oder CodingKeys. FamilyMember soll snake_case direkt verwenden (wie im RESEARCH.md Code-Example bestaetigt).

---

### `FamilyScore/Models/Family.swift` (model)

**Analog:** `FamilyScoreKit/Sources/FamilyScoreKit/WidgetData.swift`

**Pattern** (Analog: WidgetData.familyName):
```swift
struct Family: Codable, Identifiable {
    let id: UUID
    let name: String
    let created_at: Date
    let created_by: UUID?
}
```

---

### `FamilyScore/Models/FamilyInvite.swift` (model)

**Analog:** `FamilyScoreKit/Sources/FamilyScoreKit/WidgetData.swift`

**Pattern:**
```swift
struct FamilyInvite: Codable, Identifiable {
    let id: UUID
    let family_id: UUID
    let token: String
    let expires_at: Date
    let used_by: UUID?
    let used_at: Date?
    let created_at: Date
}
```

---

### `FamilyScore/Models/ChildProfile.swift` (model)

**Analog:** `FamilyScoreKit/Sources/FamilyScoreKit/WidgetData.swift`

**Pattern:**
```swift
struct ChildProfile: Codable, Identifiable {
    let id: UUID
    let family_id: UUID
    let display_name: String
    let avatar_color: String
    let created_by: UUID
    let created_at: Date
}
```

---

### `FamilyScore/Views/Family/FamilyOnboardingView.swift` (component, request-response)

**Analog:** `FamilyScore/Views/Auth/AuthFlowView.swift` (aus Plan 02-02)

**Imports + EnvironmentObject-Pattern** (Analog: AuthFlowView.swift):
```swift
import SwiftUI

struct FamilyOnboardingView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var familyService: FamilyService
    // iOS 16: @EnvironmentObject (NICHT @Environment — iOS 17+)
```

**Dark-Mode-Layout-Pattern** (Analog: AuthFlowView.swift — ZStack + Color.black.ignoresSafeArea):
```swift
var body: some View {
    NavigationStack {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 32) {
                // Header mit Image + Text
                // Aktions-Buttons (NavigationLink)
                Spacer()
                // Sekundaer-Aktion (Ausloggen)
            }
        }
        .navigationBarHidden(true)
    }
}
```

**NavigationLink-Button-Pattern** (Analog: AuthFlowView TabView, angepasst):
```swift
NavigationLink(destination: CreateFamilyView()) {
    Label("Neue Familie erstellen", systemImage: "plus.circle.fill")
        .font(.headline)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(Color.white)
        .foregroundColor(.black)
        .cornerRadius(12)
}
.padding(.horizontal, 24)
```

**Preview-Pattern** (Analog: AuthFlowView.swift #Preview):
```swift
#Preview {
    FamilyOnboardingView()
        .environmentObject(AuthService())
        .environmentObject(FamilyService())
}
```

---

### `FamilyScore/Views/Family/CreateFamilyView.swift` (component, request-response)

**Analog:** `FamilyScore/Views/Auth/RegisterView.swift` (aus Plan 02-02) — ein Text-Feld + Submit-Button

**Vollstaendiges View-Pattern** (Analog: RegisterView.swift Zeilen 1-810, vereinfacht auf ein Feld):

**Imports + State-Pattern** (Analog: RegisterView.swift Zeilen 1-15):
```swift
import SwiftUI

struct CreateFamilyView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var familyService: FamilyService

    @State private var familyName: String = ""
    @State private var isLoading: Bool = false
    @FocusState private var isFocused: Bool

    private var canSubmit: Bool {
        !familyName.trimmingCharacters(in: .whitespaces).isEmpty
    }
```

**Fehler-Banner-Pattern** (Analog: RegisterView.swift Fehler-Banner-Block):
```swift
if let error = familyService.serviceError {
    HStack {
        Image(systemName: "exclamationmark.circle.fill").foregroundColor(.red)
        Text(error).font(.subheadline).foregroundColor(.red)
        Spacer()
        Button { familyService.serviceError = nil } label: {
            Image(systemName: "xmark").foregroundColor(.secondary)
        }
    }
    .padding(12)
    .background(Color.red.opacity(0.1))
    .cornerRadius(8)
    .padding(.horizontal, 24)
}
```

**TextField-Pattern** (Analog: RegisterView.swift Name-Feld-Block):
```swift
VStack(alignment: .leading, spacing: 4) {
    Text("Familienname")
        .font(.caption).foregroundColor(.secondary)
    TextField("", text: $familyName)
        .focused($isFocused)
        .submitLabel(.done)
        .onSubmit { if canSubmit { Task { await submit() } } }
        .padding(12)
        .background(Color.white.opacity(0.08))
        .cornerRadius(8)
        .foregroundColor(.white)
}
.padding(.horizontal, 24)
```

**Submit-Button-Pattern** (Analog: RegisterView.swift "Konto erstellen"-Button):
```swift
Button {
    Task { await submit() }
} label: {
    Group {
        if isLoading { ProgressView().tint(.black) }
        else { Text("Familie erstellen").font(.headline) }
    }
    .frame(maxWidth: .infinity).frame(height: 50)
    .background(canSubmit ? Color.white : Color.white.opacity(0.3))
    .foregroundColor(.black)
    .cornerRadius(12)
}
.disabled(!canSubmit || isLoading)
.padding(.horizontal, 24)
```

**Async-Submit-Pattern** (Analog: RegisterView.swift `submitRegister()`):
```swift
private func submit() async {
    guard canSubmit else { return }
    isLoading = true
    defer { isLoading = false }
    do {
        let familyId = try await familyService.createFamily(
            name: familyName.trimmingCharacters(in: .whitespaces)
        )
        _ = familyId
        // Nach erfolgreicher RPC: AppState updaten
        await authService.refreshFamilyStatus()
        // authService.appState wechselt zu .authenticated(hasFamily: true)
        // RootView routet automatisch zu MainTabView (Phase 4) oder Placeholder
    } catch {
        familyService.serviceError = error.localizedDescription
    }
}
```

---

### `FamilyScore/Views/Family/JoinFamilyView.swift` (component, request-response)

**Analog:** `FamilyScore/Views/Auth/LoginView.swift` (aus Plan 02-02) — ein Eingabefeld + Submit

**Pattern:** Identisch zu CreateFamilyView, jedoch:
- TextField fuer 8-stelligen Invite-Code (kein Passwort-Feld)
- `.keyboardType(.asciiCapable)` + `.autocapitalization(.allCharacters)`
- Submit ruft `familyService.joinFamily(token: code)` statt `createFamily`
- Gleicher `await authService.refreshFamilyStatus()`-Aufruf danach

**Code-Input-Feld-Pattern** (Analog: LoginView.swift E-Mail-Feld, angepasst):
```swift
TextField("", text: $inviteCode)
    .keyboardType(.asciiCapable)
    .autocapitalization(.allCharacters)
    .autocorrectionDisabled()
    .focused($isFocused)
    .submitLabel(.go)
    .onChange(of: inviteCode) { _, new in
        // Auf 8 Zeichen begrenzen
        if new.count > 8 { inviteCode = String(new.prefix(8)) }
    }
    .padding(12)
    .background(Color.white.opacity(0.08))
    .cornerRadius(8)
    .foregroundColor(.white)
```

---

### `FamilyScore/Views/Family/MemberListView.swift` (component, CRUD)

**Analog:** `FamilyScore/Views/Auth/AuthFlowView.swift` (aus Plan 02-02) — List-Container-Pattern

**List-mit-Admin-Actions-Pattern** (kein exakter Analog im Codebase — naechster: ContentView.swift Task-Pattern):
```swift
struct MemberListView: View {
    @EnvironmentObject private var familyService: FamilyService

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            List(familyService.members) { member in
                MemberRow(member: member)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing) {
                        // Admin-only: Mitglied entfernen
                        Button(role: .destructive) {
                            Task { try? await familyService.removeMember(memberId: member.id) }
                        } label: {
                            Label("Entfernen", systemImage: "person.badge.minus")
                        }
                    }
            }
            .listStyle(.plain)
        }
        .task {
            // ContentView.swift-Pattern: .task{} fuer Daten laden beim Erscheinen
            if let familyId = familyService.currentFamily?.id {
                await familyService.fetchMembers(familyId: familyId)
            }
        }
    }
}
```

---

### `FamilyScore/Views/Family/InviteSheet.swift` (component, request-response)

**Analog:** `FamilyScore/Views/Auth/LoginView.swift` (aus Plan 02-02) — Button + Ergebnis anzeigen

**Sheet-Pattern** (kein exakter Analog — kombiniert aus AuthFlowView + ContentView):
```swift
struct InviteSheet: View {
    @EnvironmentObject private var familyService: FamilyService
    @Environment(\.dismiss) private var dismiss

    @State private var generatedToken: String? = nil
    @State private var isLoading: Bool = false

    var body: some View {
        // ...
        if let token = generatedToken {
            // Anzeige des 8-stelligen Codes
            Text(token)
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        } else {
            Button("Code generieren") {
                Task { await generateCode() }
            }
        }
    }
}
```

---

### `FamilyScore/Views/Family/RolePickerSheet.swift` (component, CRUD)

**Analog:** `FamilyScore/Views/Auth/LoginView.swift` (Picker + Submit)

**Picker-Pattern:**
```swift
struct RolePickerSheet: View {
    let member: FamilyMember
    @EnvironmentObject private var familyService: FamilyService
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRole: MemberRole

    init(member: FamilyMember) {
        self.member = member
        _selectedRole = State(initialValue: MemberRole(rawValue: member.role) ?? .adult)
    }

    var body: some View {
        // Picker + Bestaetigen-Button
        // Submit: try await familyService.changeMemberRole(memberId: member.id, role: selectedRole)
    }
}
```

---

### `FamilyScore/Views/Family/AddChildView.swift` (component, CRUD)

**Analog:** `FamilyScore/Views/Auth/RegisterView.swift` (aus Plan 02-02) — zwei Felder + Submit

**Pattern:** Identisch zu CreateFamilyView, jedoch:
- Zwei Felder: `displayName` (TextField) + `avatarColor` (ColorPicker oder Preset-Buttons)
- Submit ruft `familyService.createChildProfile(name:avatarColor:)` auf
- Kein `refreshFamilyStatus()`-Aufruf noetig (kein AppState-Wechsel)

---

### `FamilyScore/Views/RootView.swift` (component, request-response) — MODIFY

**Analog:** `FamilyScore/Views/RootView.swift` (Plan 02-02, wird modifiziert)

**Einzige Aenderung:** `OnboardingPlaceholderView()` → `FamilyOnboardingView()` ersetzen:
```swift
// Vorher (Plan 02-02):
case .authenticated(hasFamily: false):
    OnboardingPlaceholderView()

// Nachher (Phase 3):
case .authenticated(hasFamily: false):
    FamilyOnboardingView()
    // FamilyService als EnvironmentObject muss in FamilyScoreApp.swift injiziert werden
```

**Alle anderen Teile von RootView.swift unveraendert lassen.**

---

### `FamilyScore/Services/AuthService.swift` (service, event-driven) — MODIFY

**Analog:** `FamilyScore/Services/AuthService.swift` (Plan 02-02, wird erweitert)

**Einzige Ergaenzung:** `refreshFamilyStatus()`-Methode hinzufuegen:
```swift
// Ergaenzung zu AuthService.swift (NICHT bestehende Methoden aendern)
// Wird nach createFamily() und joinFamily() von der View aufgerufen

func refreshFamilyStatus() async {
    guard let userId = currentUser?.id else { return }
    let hasFamily = await checkFamilyMembership(userId: userId)
    appState = .authenticated(hasFamily: hasFamily)
}
// checkFamilyMembership() ist bereits privat in AuthService definiert (Plan 02-02)
// Diese Methode ist intern aufrufbar — Sichtbarkeit auf internal belassen (kein public)
```

---

### `FamilyScoreTests/Mocks/MockFamilyService.swift` (test)

**Analog:** `FamilyScoreTests/Mocks/MockAuthService.swift` (aus Plan 02-01)

**Protocol + Mock-Pattern** (Analog: MockAuthService.swift vollstaendig):
```swift
// FamilyScoreTests/Mocks/MockFamilyService.swift
// Target Membership: FamilyScoreTests ONLY

import Foundation
import Combine
@testable import FamilyScore

@MainActor
protocol FamilyServiceProtocol: AnyObject {
    var members: [FamilyMember] { get }
    var currentFamily: Family? { get }
    var childProfiles: [ChildProfile] { get }
    var serviceError: String? { get set }
}

@MainActor
final class MockFamilyService: ObservableObject, FamilyServiceProtocol {
    @Published private(set) var currentFamily: Family?
    @Published private(set) var members: [FamilyMember] = []
    @Published private(set) var childProfiles: [ChildProfile] = []
    @Published var serviceError: String? = nil

    // Verhalten-Flags fuer Unit-Tests (Muster: MockAuthService)
    var shouldThrowOnCreateFamily: Bool = false
    var shouldThrowOnJoinFamily: Bool = false
    var createFamilyCallCount: Int = 0
    var joinFamilyCallCount: Int = 0
    var lastJoinToken: String? = nil

    init(initialMembers: [FamilyMember] = [], initialFamily: Family? = nil) {
        self.members = initialMembers
        self.currentFamily = initialFamily
    }

    func createFamily(name: String) async throws -> UUID {
        createFamilyCallCount += 1
        if shouldThrowOnCreateFamily { throw MockFamilyError.createFailed }
        let id = UUID()
        currentFamily = Family(id: id, name: name, created_at: Date(), created_by: nil)
        return id
    }

    func joinFamily(token: String) async throws -> UUID {
        joinFamilyCallCount += 1
        lastJoinToken = token
        if shouldThrowOnJoinFamily { throw MockFamilyError.invalidToken }
        let id = UUID()
        return id
    }

    // ... weitere Methoden analog zu MockAuthService
}

enum MockFamilyError: Error {
    case createFailed
    case invalidToken
    case insufficientPermissions
}
```

---

## Shared Patterns

### ObservableObject + MainActor
**Quelle:** `FamilyScore/Services/AuthService.swift` (Plan 02-02)
**Anwenden auf:** `FamilyService.swift`
```swift
@MainActor
final class XxxService: ObservableObject {
    @Published private(set) var someState: SomeType = defaultValue
    @Published var serviceError: String? = nil
    // iOS 16: KEIN @Observable — verboten per CLAUDE.md
}
```

### EnvironmentObject-Injektion (iOS 16)
**Quelle:** `FamilyScore/Views/Auth/LoginView.swift` (Plan 02-02)
**Anwenden auf:** Alle Family-Views
```swift
// iOS 16: @EnvironmentObject (NICHT @Environment — nur iOS 17+)
@EnvironmentObject private var familyService: FamilyService
@EnvironmentObject private var authService: AuthService
```

### Dark-Mode-Layout-Basis
**Quelle:** `FamilyScore/Views/Auth/AuthFlowView.swift` (Plan 02-02)
**Anwenden auf:** Alle Family-Views
```swift
ZStack {
    Color.black.ignoresSafeArea()   // Hintergrund immer schwarz
    VStack(spacing: 16/24/32) {     // Spacing nach Hierarchy
        // ...
    }
}
```

### Async-Submit mit isLoading + defer
**Quelle:** `FamilyScore/Views/Auth/LoginView.swift` (Plan 02-02, `submitLogin()`)
**Anwenden auf:** CreateFamilyView, JoinFamilyView, AddChildView, InviteSheet
```swift
private func submit() async {
    guard canSubmit else { return }
    isLoading = true
    defer { isLoading = false }
    do {
        try await service.someAction(...)
    } catch {
        service.serviceError = error.localizedDescription
    }
}
```

### Supabase REST-Abfrage-Kette
**Quelle:** `FamilyScore/FamilyScore/FamilyScoreApp.swift` (verifySupabaseConnection, Zeilen 32-38)
**Anwenden auf:** FamilyService.fetchMembers, fetchFamily, fetchChildProfiles
```swift
// Muster: .from → .select → .eq → .order/.limit → .execute → .value
let result: [ModelType] = try await supabase
    .from("table_name")
    .select()
    .eq("column", value: someValue)
    .order("created_at", ascending: true)
    .execute()
    .value
```

### SECURITY DEFINER + set search_path = ''
**Quelle:** `supabase/migrations/20260515_initial_schema.sql` (Zeilen 33-48, `handle_new_user`)
**Anwenden auf:** Alle neuen RPC-Funktionen in Phase 3 SQL
```sql
create or replace function public.function_name(param_name type)
returns return_type
language plpgsql
security definer
set search_path = ''  -- Pflicht: verhindert search_path Injection
as $$
begin
  -- Sicherheitscheck zuerst
  if not exists (...) then raise exception '...'; end if;
  -- Datenaenderungen
end;
$$;
```

### Supabase-Global-Client
**Quelle:** `FamilyScore/FamilyScore/Supabase.swift` (Zeilen 1-19)
**Anwenden auf:** FamilyService.swift — einfach `supabase` verwenden (global, kein Import noetig)
```swift
// Supabase.swift definiert: let supabase = SupabaseClient(...)
// FamilyService importiert nur Foundation + Supabase und nutzt den globalen Client
// NIEMALS einen zweiten SupabaseClient instanziieren
```

### Mock-Verhalten-Flags fuer Tests
**Quelle:** `FamilyScoreTests/Mocks/MockAuthService.swift` (Plan 02-01, Zeilen 17-25)
**Anwenden auf:** MockFamilyService.swift
```swift
var shouldThrowOn[Action]: Bool = false
var [action]CallCount: Int = 0
var last[Action]Param: ParamType? = nil
```

---

## Keine Analogs gefunden

| Datei | Rolle | Data Flow | Grund |
|-------|-------|-----------|-------|
| `FamilyScore/Views/Family/MemberListView.swift` (List mit SwipeActions) | component | CRUD | Kein List-View mit swipeActions im Codebase — naechster Analog ist ContentView.swift (zu simpel); RESEARCH.md Pattern 6 verwenden |
| `FamilyScore/Views/Family/InviteSheet.swift` (Token-Anzeige nach Generierung) | component | request-response | Kein .sheet-Pattern im Codebase — RESEARCH.md Code-Beispiel "Einladung generieren" als Vorlage |

---

## Wichtige Architektur-Constraints fuer Phase 3

Diese Constraints sind aus CLAUDE.md und RESEARCH.md abgeleitet — muessen in jedem Plan beachtet werden:

| Constraint | Quelle | Gilt fuer |
|-----------|--------|-----------|
| `ObservableObject` statt `@Observable` | CLAUDE.md "iOS 16.0 Minimum" | FamilyService, MockFamilyService |
| Supabase SDK nie im Widget-Target | CLAUDE.md | FamilyService bleibt im App-Target |
| Multi-Tabellen-Ops immer via RPC | RESEARCH.md Anti-Patterns | create_family, accept_invite, remove_member, change_member_role |
| Admin-Check immer serverseitig | RESEARCH.md Anti-Patterns | Alle Admin-Aktionen via SECURITY DEFINER |
| `refreshFamilyStatus()` nach RPC | RESEARCH.md Pattern 7, Pitfall 3 | CreateFamilyView.submit(), JoinFamilyView.submit() |
| RLS nur mit echtem JWT testen | CLAUDE.md | Alle neuen Policies + RPCs |
| Token-Generierung serverseitig | RESEARCH.md Don't Hand-Roll | Invite-Token via DB-Default, nie Swift-Client |
| `(select auth.uid())` statt `auth.uid()` in Policies | RESEARCH.md State of the Art | Alle Phase 3 RLS-Policies |

---

## Metadata

**Analog-Suchbereich:** `FamilyScore/` (Swift-Dateien), `supabase/migrations/` (SQL-Dateien)
**Gescannte Dateien:** 7 Swift-Dateien, 1 SQL-Migration
**Wichtig:** Phase 2 (AuthService, LoginView, RegisterView etc.) ist noch nicht ausgefuehrt — die Analogs fuer Phase 3 kommen aus den Plan-Dokumenten (02-01-PLAN.md, 02-02-PLAN.md), die den vollstaendigen Implementierungscode enthalten. Der Planner muss sicherstellen, dass Phase 2 vor Phase 3 ausgefuehrt wird.
**Pattern-Mapping-Datum:** 2026-05-15
