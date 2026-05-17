# Phase 6: Settings & Polish — Pattern Map

**Mapped:** 2026-05-17
**Files analyzed:** 14 new/modified files
**Analogs found:** 11 / 14

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `FamilyScore/FamilyScore/Services/CategoryService.swift` | service | CRUD | `FamilyScore/FamilyScore/Services/FamilyService.swift` | exact |
| `FamilyScore/FamilyScore/Models/CategoryConfig.swift` | model | — | `FamilyScore/FamilyScore/Models/FamilyMember.swift` | exact |
| `FamilyScore/FamilyScore/Views/Settings/SettingsView.swift` | component | request-response | `FamilyScore/FamilyScore/Views/Family/MemberListView.swift` | role-match |
| `FamilyScore/FamilyScore/Views/Settings/CategorySettingsView.swift` | component | CRUD | `FamilyScore/FamilyScore/Views/Family/MemberListView.swift` | exact |
| `FamilyScore/FamilyScore/Views/Settings/MemberSettingsView.swift` | component | CRUD | `FamilyScore/FamilyScore/Views/Family/MemberListView.swift` | exact |
| `FamilyScore/FamilyScore/Views/Kid/KindDashboardView.swift` | component | request-response | `FamilyScore/FamilyScore/Views/Family/MemberListView.swift` | role-match |
| `FamilyScore/FamilyScore/Resources/PrivacyInfo.xcprivacy` | config | — | — | no analog |
| `fastlane/Fastfile` | config | — | — | no analog |
| `fastlane/Matchfile` | config | — | — | no analog |
| `fastlane/Appfile` | config | — | — | no analog |
| `.github/workflows/release.yml` | config | — | `.github/workflows/build.yml` | role-match |
| `FamilyScore/project.yml` (MODIFY) | config | — | `FamilyScore/project.yml` | exact (self) |
| `FamilyScore/FamilyScore/Views/RootView.swift` (MODIFY) | component | request-response | `FamilyScore/FamilyScore/Views/RootView.swift` | exact (self) |
| `FamilyScore/FamilyScore/Views/MainTabView.swift` (MODIFY) | component | request-response | `FamilyScore/FamilyScore/Views/Family/MemberListView.swift` | role-match |

---

## Pattern Assignments

### `FamilyScore/FamilyScore/Services/CategoryService.swift` (service, CRUD)

**Analog:** `FamilyScore/FamilyScore/Services/FamilyService.swift`

**File header + imports pattern** (lines 1–9):
```swift
// FamilyScore/Services/CategoryService.swift
// Target Membership: FamilyScore (App) ONLY
// iOS 16.0 Minimum: ObservableObject + @Published (KEIN @Observable -- iOS 17+)
// NIEMALS Supabase SDK im Widget-Target -- gilt auch fuer diesen Service

import Foundation
@preconcurrency import Supabase
```

**Class declaration pattern** (lines 10–17):
```swift
@MainActor
final class FamilyService: ObservableObject {

    @Published private(set) var currentFamily: Family?
    @Published private(set) var members: [FamilyMember] = []
    @Published var serviceError: String? = nil
```

**Fetch method pattern** (lines 35–48 in FamilyService.swift):
```swift
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
Copy this for `fetchCategories(familyId:)` — replace table `"family_members"` with `"category_config"`, `.order("created_at")` with `.order("sort_order")`, and the assignment target.

**REST UPDATE pattern** (lines 209–231 in FamilyService.swift — `updateProfile`):
```swift
func updateProfile(displayName: String, avatarColor: String) async throws {
    struct ProfileUpdate: Encodable {
        let display_name: String
        let avatar_color: String
        let updated_at: Date
    }
    // ...
    try await supabase
        .from("family_members")
        .update(ProfileUpdate(...))
        .eq("id", value: currentUserId.uuidString)
        .execute()
}
```
Copy this for `toggleCategory(id:isEnabled:)` and `updateWeight(id:weight:)` — replace table, struct fields, and `.eq` filter.

**Error enum pattern** (lines 277–297 in FamilyService.swift):
```swift
enum FamilyServiceError: Error, LocalizedError {
    case notAuthenticated
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Bitte zuerst einloggen."
        case .unknown(let msg): return msg
        }
    }
}
```
Create a parallel `CategoryServiceError` enum with cases `fetchFailed`, `updateFailed`, `unknown(String)`.

**Widget reload addition** — unique to CategoryService, not in any analog. After every state mutation:
```swift
WidgetCenter.shared.reloadAllTimelines()
```
Requires `import WidgetKit` at the top.

**Optimistic local state update** — pattern from RESEARCH.md Pattern 1:
```swift
if let idx = categories.firstIndex(where: { $0.id == id }) {
    categories[idx].isEnabled = isEnabled
}
```
Apply after the Supabase write, revert on error.

---

### `FamilyScore/FamilyScore/Models/CategoryConfig.swift` (model)

**Analog:** `FamilyScore/FamilyScore/Models/FamilyMember.swift` (lines 1–13)

**Struct pattern:**
```swift
// FamilyScore/Models/FamilyMember.swift
import Foundation

struct FamilyMember: Codable, Identifiable {
    let id: UUID
    let family_id: UUID?
    let display_name: String
    let avatar_color: String
    let role: String          // String statt MemberRole: robuster bei unbekannten DB-Werten
    let created_at: Date
}
```
Copy this pattern. `CategoryConfig` maps to the `category_config` DB table:
- `id: UUID`
- `family_id: UUID`
- `name: String` (display name, e.g. "Haushalt")
- `icon: String` (SF Symbol name)
- `is_enabled: Bool` — use `var` (mutable for optimistic updates)
- `point_weight: Double` — use `var`
- `sort_order: Int`
- `created_at: Date`

Note: unlike `FamilyMember`, `is_enabled` and `point_weight` must be `var` (not `let`) to support optimistic in-place mutation in `CategoryService`.

---

### `FamilyScore/FamilyScore/Views/Settings/SettingsView.swift` (component, request-response)

**Analog:** `FamilyScore/FamilyScore/Views/Family/MemberListView.swift`

**ZStack + List shell pattern** (lines 20–83 in MemberListView.swift):
```swift
var body: some View {
    ZStack {
        Color.black.ignoresSafeArea()
        List {
            Section {
                // rows
            } header: {
                Text("Mitglieder")
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .textCase(nil)
            }
        }
        .listStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
    .navigationTitle("Familie")
    .navigationBarTitleDisplayMode(.large)
```
Copy this shell. Sections in SettingsView: "Kategorien", "Mitglieder", "App". Each section contains a `NavigationLink` to the relevant sub-view.

**Row background pattern** (line 28 in MemberListView.swift):
```swift
.listRowBackground(Color.white.opacity(0.05))
```
Apply to all List rows.

**Error overlay pattern** (lines 116–133 in MemberListView.swift):
```swift
.overlay {
    if let error = familyService.serviceError {
        VStack {
            Spacer()
            HStack {
                Text(error).font(.subheadline).foregroundColor(.white)
                Spacer()
                Button { familyService.serviceError = nil } label: {
                    Image(systemName: "xmark").foregroundColor(.white)
                }
            }
            .padding()
            .background(Color.red.opacity(0.85))
            .cornerRadius(12)
            .padding()
        }
    }
}
```
Copy verbatim for all Settings views — swap `familyService.serviceError` with `categoryService.serviceError` or local `@State var errorMessage: String?` as appropriate.

**EnvironmentObject injection pattern** (line 7 in MemberListView.swift):
```swift
@EnvironmentObject private var familyService: FamilyService
```
SettingsView will need both `familyService` and `categoryService`.

**Admin guard in Tab** — from RESEARCH.md Pattern 3 (no codebase analog yet):
```swift
// In MainTabView:
if appState.currentMember?.role == .admin {
    Tab("Einstellungen", systemImage: "gear") {
        SettingsView()
    }
}
```

---

### `FamilyScore/FamilyScore/Views/Settings/CategorySettingsView.swift` (component, CRUD)

**Analog:** `FamilyScore/FamilyScore/Views/Family/MemberListView.swift`

**Same ZStack + List shell** as SettingsView (see above).

**Async action in swipeAction/button pattern** (lines 32–44 in MemberListView.swift):
```swift
Button(role: .destructive) {
    Task {
        do {
            try await familyService.removeMember(memberId: member.id)
            // refresh
        } catch {
            familyService.serviceError = error.localizedDescription
        }
    }
} label: { ... }
```
Adapt for Toggle/Stepper actions:
```swift
Toggle(isOn: $category.isEnabled) {
    // label
}
.tint(Color.white.opacity(0.9))
.onChange(of: category.isEnabled) { newValue in
    Task {
        do {
            try await categoryService.toggleCategory(id: category.id, isEnabled: newValue)
        } catch {
            // revert + show error
            categoryService.serviceError = "Kategorie konnte nicht geändert werden. Bitte versuche es erneut."
        }
    }
}
```

**Loading state pattern** (line 34 in RolePickerSheet.swift):
```swift
if isLoading { ProgressView().scaleEffect(0.8) }
else { Text("Bestaetigen").bold() }
```
Use `ProgressView()` in trailing position of row during async write.

---

### `FamilyScore/FamilyScore/Views/Settings/MemberSettingsView.swift` (component, CRUD)

**Analog:** `FamilyScore/FamilyScore/Views/Family/MemberListView.swift` + `FamilyScore/FamilyScore/Views/Family/RolePickerSheet.swift`

**MemberRow pattern** (lines 139–174 in MemberListView.swift):
```swift
struct MemberRow: View {
    let member: FamilyMember
    let isAdmin: Bool

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: member.avatar_color) ?? .blue)
                .frame(width: 44, height: 44)
                .overlay {
                    Text(String(member.display_name.prefix(1)).uppercased())
                        .font(.headline)
                        .foregroundColor(.white)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(member.display_name)
                    .foregroundColor(.white)
                    .font(.body)
                // role badge
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
```
Reuse this row structure. Add a `Picker("Modus", selection: $selectedRole)` with `.pickerStyle(.menu)` after `Spacer()` instead of swipe actions.

**changeMemberRole call pattern** (lines 102–115 in RolePickerSheet.swift):
```swift
private func confirmRoleChange() async {
    isLoading = true
    defer { isLoading = false }
    do {
        try await familyService.changeMemberRole(memberId: member.id, role: selectedRole)
        if let familyId = familyService.currentFamily?.id {
            await familyService.fetchMembers(familyId: familyId)
        }
        dismiss()
    } catch {
        familyService.serviceError = error.localizedDescription
    }
}
```
Inline this as a `Task { }` in `.onChange(of: selectedRole)` — no dismiss needed (list stays open).

**Task-based initial load** (lines 110–115 in MemberListView.swift):
```swift
.task {
    if let familyId = familyService.currentFamily?.id {
        await familyService.fetchMembers(familyId: familyId)
        await familyService.fetchChildProfiles(familyId: familyId)
    }
}
```
Copy for MemberSettingsView — only `fetchMembers`, no `fetchChildProfiles`.

---

### `FamilyScore/FamilyScore/Views/Kid/KindDashboardView.swift` (component, request-response)

**Analog:** `FamilyScore/FamilyScore/Views/Family/MemberListView.swift` (structure only — no List, single NavigationStack)

**Black background pattern** (line 21 in MemberListView.swift):
```swift
ZStack {
    Color.black.ignoresSafeArea()
    // content
}
```

**NavigationStack + large title** (lines 84–86 in MemberListView.swift):
```swift
.navigationTitle("Familie")
.navigationBarTitleDisplayMode(.large)
```
Use `.navigationTitle("Mein Score")` + `.navigationBarTitleDisplayMode(.large)`.

**EnvironmentObject injection** (line 7 in MemberListView.swift):
```swift
@EnvironmentObject private var familyService: FamilyService
```
KindDashboardView will inject `activityService: ActivityService` (Phase 4 service).

**Error overlay** — copy exactly from MemberListView lines 116–133 (see above).

**Touch target sizing** (line 148 in MemberListView.swift):
```swift
.frame(width: 44, height: 44)
```
All interactive elements minimum 44pt. Primary action buttons use `.frame(maxWidth: .infinity)` + `.frame(height: 50)` from LoginView pattern.

**No TabView** — KindDashboardView is a bare `NavigationStack`, not embedded in a `TabView`. This is the key structural difference from MainTabView.

---

### `FamilyScore/FamilyScore/Views/RootView.swift` (MODIFY — child role routing)

**Self-analog:** `FamilyScore/FamilyScore/Views/RootView.swift`

**Existing switch pattern** (lines 16–33):
```swift
switch authService.appState {
case .loading:
    ProgressView()
        .tint(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)

case .unauthenticated:
    AuthFlowView()

case .authenticated(hasFamily: false):
    FamilyOnboardingView()

case .authenticated(hasFamily: true):
    // Phase 4 liefert MainTabView
    AuthenticatedPlaceholderView()
}
```
Phase 6 modifies only the `case .authenticated(hasFamily: true):` branch. Replace `AuthenticatedPlaceholderView()` with a nested role check:
```swift
case .authenticated(hasFamily: true):
    // Phase 6: Kind-Routing
    if let member = familyService.currentMember, member.role == "child" {
        KindDashboardView()
            .environmentObject(activityService)
    } else {
        MainTabView()
            .environmentObject(activityService)
            .environmentObject(categoryService)
    }
```
Note: `familyService.currentMember` needs to be the logged-in user's `FamilyMember`. Verify actual property name against Phase 4's FamilyService extensions; RESEARCH.md assumption A3 flags this as unverified.

**Debug overlay** (lines 36–38) — preserve unchanged:
```swift
#if DEBUG
DebugStateOverlay(appState: authService.appState, error: authService.authError)
#endif
```

---

### `FamilyScore/FamilyScore/Views/MainTabView.swift` (MODIFY — conditional Settings tab)

**Analog:** `FamilyScore/FamilyScore/Views/Family/MemberListView.swift` (admin guard pattern)

**Admin guard pattern** (lines 14–17 in MemberListView.swift):
```swift
private var currentUserIsAdmin: Bool {
    familyService.members.contains { $0.role == "admin" }
}
```
Phase 6 uses the logged-in member's own role instead of a group check. The conditional tab:
```swift
// In TabView / Tab builder:
if currentMember?.role == "admin" {
    Tab("Einstellungen", systemImage: "gear") {
        NavigationStack {
            SettingsView()
                .environmentObject(categoryService)
                .environmentObject(familyService)
        }
    }
}
```
Per UI-SPEC: Settings tab is absent for non-admins, not locked/hidden.

---

### `FamilyScore/project.yml` (MODIFY — add PrivacyInfo resource)

**Self-analog:** `FamilyScore/project.yml`

**Existing sources pattern** (lines 22–23):
```yaml
  FamilyScore:
    type: application
    platform: iOS
    sources:
      - path: FamilyScore
```
XcodeGen's `sources: - path: FamilyScore` auto-includes all files under that directory. Adding `FamilyScore/Resources/PrivacyInfo.xcprivacy` under `FamilyScore/Resources/` is sufficient — no explicit `resources:` list needed if the file is already inside the `FamilyScore/` source path.

If an explicit entry is needed (for resource type declaration):
```yaml
    resources:
      - path: FamilyScore/Resources/PrivacyInfo.xcprivacy
        buildPhase: resources
```

**Widget Extension bundle ID** (lines 56–57 — already present, reference only):
```yaml
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.familyscore.widget
```
This confirms the Widget Extension bundle ID for fastlane match provisioning profiles: `com.familyscore.widget`.

---

### `.github/workflows/release.yml` (NEW)

**Analog:** `.github/workflows/build.yml`

**Workflow trigger + runner pattern** (lines 1–26 in build.yml):
```yaml
name: iOS Build & Test
on:
  push:
    branches: [master]
env:
  FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true
jobs:
  build-and-test:
    runs-on: macos-15
```
Release workflow uses `workflow_dispatch` (manual trigger only) instead of push trigger. Same `runs-on: macos-15`.

**Xcode selection step** (lines 30–35 in build.yml):
```yaml
- name: Select Xcode 16
  run: |
    XCODE=$(ls /Applications/ | grep "^Xcode_16" | sort -V | tail -1)
    sudo xcode-select -s "/Applications/$XCODE/Contents/Developer"
    xcodebuild -version
```
Copy verbatim to release.yml.

**Secrets.xcconfig creation step** (lines 43–51 in build.yml):
```yaml
- name: Create Secrets.xcconfig
  run: |
    SUPABASE_HOST=$(echo "${{ secrets.SUPABASE_URL_SECRET }}" | sed 's|https://||')
    cat > FamilyScore/Config/Secrets.xcconfig << EOF
    SUPABASE_URL_SECRET = $SUPABASE_HOST
    SUPABASE_KEY_SECRET = ${{ secrets.SUPABASE_KEY_SECRET }}
    EOF
```
Copy verbatim — release build needs same secrets.

**XcodeGen step** (lines 53–55 in build.yml):
```yaml
- name: Generate Xcode Project
  working-directory: FamilyScore
  run: xcodegen generate --spec project.yml
```
Copy verbatim.

**SPM cache step** (lines 58–65 in build.yml):
```yaml
- name: Cache SPM packages
  uses: actions/cache@v4
  with:
    path: ~/spm-packages
    key: ${{ runner.os }}-spm-${{ hashFiles('FamilyScore/project.yml') }}
    restore-keys: |
      ${{ runner.os }}-spm-
```
Copy verbatim — release build benefits from same cache.

Release-specific additions (from RESEARCH.md Pattern 4):
```yaml
- name: Setup Ruby
  uses: ruby/setup-ruby@v1
  with:
    ruby-version: '3.4'
    bundler-cache: true

- name: Run fastlane release_appstore
  run: bundle exec fastlane release_appstore
  env:
    ASC_KEY_ID: ${{ secrets.ASC_KEY_ID }}
    ASC_ISSUER_ID: ${{ secrets.ASC_ISSUER_ID }}
    ASC_KEY: ${{ secrets.ASC_KEY }}
    MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
    MATCH_GIT_URL: ${{ secrets.MATCH_GIT_URL }}
    MATCH_GIT_BASIC_AUTHORIZATION: ${{ secrets.MATCH_GIT_BASIC_AUTHORIZATION }}
```

---

### `fastlane/Fastfile`, `fastlane/Matchfile`, `fastlane/Appfile` (NEW)

**No codebase analog.** Use RESEARCH.md Pattern 4 directly (fully cited fastlane patterns):

- `Fastfile` — `release_appstore` lane with `app_store_connect_api_key` + `setup_ci` + `match(type: "appstore", readonly: is_ci)` + `build_app(export_method: "app-store")` + `upload_to_testflight`
- `Matchfile` — `git_url(ENV["MATCH_GIT_URL"])`, `app_identifier(["com.familyscore", "com.familyscore.widget"])`, `type("appstore")`
- `Appfile` — `app_identifier("com.familyscore")`, `apple_id(ENV["APPLE_ID"])`

Key pitfall from RESEARCH.md Pitfall 5: both targets need explicit provisioning profile entries in `build_app`:
```ruby
export_options: {
  provisioningProfiles: {
    "com.familyscore" => "match AppStore com.familyscore",
    "com.familyscore.widget" => "match AppStore com.familyscore.widget"
  }
}
```

---

### `FamilyScore/FamilyScore/Resources/PrivacyInfo.xcprivacy` (NEW)

**No codebase analog.** Static XML file. Use RESEARCH.md Pattern 5 verbatim — the template is fully specified with:
- `NSPrivacyTracking: false`
- `NSPrivacyTrackingDomains: []`
- `NSPrivacyAccessedAPITypeUserDefaults` with reason `CA92.1` (App Group)
- `NSPrivacyAccessedAPITypeFileTimestamp` with reason `3B52.1` (supabase-swift transitive)

---

### Test files: `CategoryServiceTests.swift` + `MockCategoryService.swift` (NEW)

**Analog:** `FamilyScore/FamilyScoreTests/FamilyServiceTests.swift` + `FamilyScore/FamilyScoreTests/Mocks/MockFamilyService.swift`

**Test class pattern** (lines 1–23 in FamilyServiceTests.swift):
```swift
import XCTest
@testable import FamilyScore

@MainActor
final class FamilyServiceTests: XCTestCase {

    var mock: MockFamilyService!

    override func setUp() async throws {
        try await super.setUp()
        mock = MockFamilyService()
    }

    override func tearDown() async throws {
        mock = nil
        try await super.tearDown()
    }
```
Copy verbatim, replace `MockFamilyService` with `MockCategoryService`.

**Test method pattern** (lines 25–30):
```swift
func testCreateFamilySetsCurrentFamily() async throws {
    XCTAssertNil(mock.currentFamily)
    let familyId = try await mock.createFamily(name: "Muster-Familie")
    XCTAssertNotNil(mock.currentFamily)
    XCTAssertEqual(mock.createFamilyCallCount, 1)
}
```
Write equivalent tests: `testToggleCategoryUpdatesLocalState()`, `testEnabledCategoriesFilter()`, `testUpdateWeightUpdatesLocalState()`.

**Protocol + Mock pattern** (lines 10–27 in MockFamilyService.swift):
```swift
@MainActor
protocol FamilyServiceProtocol: AnyObject {
    var currentFamily: Family? { get }
    var members: [FamilyMember] { get }
    var serviceError: String? { get set }
    func fetchMembers(familyId: UUID) async
    // ...
}

@MainActor
final class MockFamilyService: ObservableObject, FamilyServiceProtocol {
    @Published private(set) var currentFamily: Family?
    var shouldThrowOnCreateFamily: Bool = false
    var createFamilyCallCount: Int = 0
```
Copy this Protocol + Mock pattern:
- `CategoryServiceProtocol` with `categories`, `enabledCategories`, `fetchCategories(familyId:)`, `toggleCategory(id:isEnabled:)`, `updateWeight(id:weight:)`
- `MockCategoryService` with `shouldThrowOnToggle`, `shouldThrowOnUpdateWeight`, `toggleCallCount`, `updateWeightCallCount`, `lastToggledId`, `lastUpdatedWeight`

---

## Shared Patterns

### Black Background + ZStack
**Source:** `FamilyScore/FamilyScore/Views/Family/MemberListView.swift` lines 20–22
**Apply to:** All Phase 6 views (SettingsView, CategorySettingsView, MemberSettingsView, KindDashboardView)
```swift
ZStack {
    Color.black.ignoresSafeArea()
    // content
}
```

### Error Banner Overlay
**Source:** `FamilyScore/FamilyScore/Views/Family/MemberListView.swift` lines 116–133
**Apply to:** CategorySettingsView, MemberSettingsView, KindDashboardView
```swift
.overlay {
    if let error = serviceError {
        VStack {
            Spacer()
            HStack {
                Text(error).font(.subheadline).foregroundColor(.white)
                Spacer()
                Button { serviceError = nil } label: {
                    Image(systemName: "xmark").foregroundColor(.white)
                }
            }
            .padding()
            .background(Color.red.opacity(0.85))
            .cornerRadius(12)
            .padding()
        }
    }
}
```

### List Style
**Source:** `FamilyScore/FamilyScore/Views/Family/MemberListView.swift` lines 81–83
**Apply to:** SettingsView, CategorySettingsView, MemberSettingsView
```swift
.listStyle(.grouped)
.scrollContentBackground(.hidden)
```

### List Row Background
**Source:** `FamilyScore/FamilyScore/Views/Family/MemberListView.swift` line 28
**Apply to:** All List rows in Phase 6 views
```swift
.listRowBackground(Color.white.opacity(0.05))
```

### Async Task Error Pattern
**Source:** `FamilyScore/FamilyScore/Views/Family/MemberListView.swift` lines 33–41
**Apply to:** All async actions in CategorySettingsView and MemberSettingsView
```swift
Task {
    do {
        try await service.action(...)
    } catch {
        service.serviceError = error.localizedDescription
    }
}
```

### @EnvironmentObject + @Published Service Pattern
**Source:** `FamilyScore/FamilyScore/Services/FamilyService.swift` lines 10–17
**Apply to:** CategoryService (service declaration) + all Phase 6 views (injection)
```swift
// Service:
@MainActor
final class SomeService: ObservableObject {
    @Published private(set) var items: [Item] = []
    @Published var serviceError: String? = nil
}
// View:
@EnvironmentObject private var someService: SomeService
```

### Section Header Style
**Source:** `FamilyScore/FamilyScore/Views/Family/MemberListView.swift` lines 58–63
**Apply to:** All List sections in Phase 6 views
```swift
} header: {
    Text("Abschnittsname")
        .foregroundColor(.secondary)
        .font(.caption)
        .textCase(nil)
}
```

### navigationBarTitleDisplayMode
**Source:** `FamilyScore/FamilyScore/Views/Family/MemberListView.swift` line 86
**Apply to:** SettingsView, CategorySettingsView, MemberSettingsView, KindDashboardView
```swift
.navigationBarTitleDisplayMode(.large)
```

### MemberRole Enum (existing — reuse unchanged)
**Source:** `FamilyScore/FamilyScore/Models/MemberRole.swift`
```swift
enum MemberRole: String, Codable, CaseIterable {
    case admin
    case adult
    case child

    var displayName: String { ... }  // "Erwachsen", "Kind-vereinfacht"
}
```
Use `MemberRole.child.rawValue == "child"` for RootView role routing check. Use `MemberRole(rawValue: member.role)` for Picker binding (same pattern as RolePickerSheet line 16).

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `FamilyScore/FamilyScore/Resources/PrivacyInfo.xcprivacy` | config | — | No privacy manifest in codebase; static XML, use RESEARCH.md Pattern 5 |
| `fastlane/Fastfile` | config | — | No fastlane configuration exists; use RESEARCH.md Pattern 4 |
| `fastlane/Matchfile` | config | — | No fastlane configuration exists; use RESEARCH.md Pattern 4 |
| `fastlane/Appfile` | config | — | No fastlane configuration exists; use RESEARCH.md Pattern 4 |

---

## Key Findings for Planner

1. **CategoryService copies FamilyService exactly** — `@MainActor final class`, `@Published private(set)`, `@preconcurrency import Supabase`, error enum pattern, inline `struct Patch: Encodable` for updates. Only difference: `WidgetCenter.shared.reloadAllTimelines()` call after mutations, and mutable `var` fields in CategoryConfig for optimistic updates.

2. **All Settings views copy MemberListView shell** — ZStack + `Color.black.ignoresSafeArea()` + `List(.grouped)` + `.scrollContentBackground(.hidden)` + section headers + `.listRowBackground(Color.white.opacity(0.05))` + error overlay is the exact template.

3. **MemberSettingsView wraps existing FamilyService.changeMemberRole()** — no new RPC needed. The call pattern is already proven in RolePickerSheet lines 102–115. Phase 6 inlines it as `.onChange(of:)` Task instead of a sheet.

4. **RootView modification is minimal** — only the `case .authenticated(hasFamily: true):` branch changes. Existing switch structure and DebugStateOverlay stay identical.

5. **Widget Extension bundle ID is `com.familyscore.widget`** — confirmed from project.yml line 57. Use this exact string in fastlane Matchfile and `export_options.provisioningProfiles`.

6. **AppState has no `currentMember` property yet** — RESEARCH.md assumption A3. Phase 4's MainTabView integration determines the actual property name. RootView child routing must read the current member's role from FamilyService or an extended AppState; verify before implementing.

7. **Tests follow Protocol + Mock pattern** — CategoryServiceProtocol must be defined alongside MockCategoryService, mirroring `FamilyServiceProtocol` in MockFamilyService.swift lines 10–27.

---

## Metadata

**Analog search scope:** `FamilyScore/FamilyScore/Services/`, `FamilyScore/FamilyScore/Models/`, `FamilyScore/FamilyScore/Views/`, `FamilyScore/FamilyScoreTests/`, `.github/workflows/`
**Files scanned:** 14 (6 models, 2 services, 4 views/sheets, 2 test files, 1 workflow, 1 project.yml)
**Pattern extraction date:** 2026-05-17
