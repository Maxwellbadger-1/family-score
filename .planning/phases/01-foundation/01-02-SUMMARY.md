---
plan: 01-02
phase: 01-foundation
status: complete
completed: 2026-05-15
---

# Plan 01-02: FamilyScoreKit Swift Package — Summary

## What Was Built

Created the local Swift Package `FamilyScoreKit` that serves as the shared module between the FamilyScore App target and the FamilyScoreWidgetExtension target.

## Files Created

- `FamilyScore/FamilyScoreKit/Package.swift` — SPM manifest, no external dependencies, iOS 16+ minimum
- `FamilyScore/FamilyScoreKit/Sources/FamilyScoreKit/WidgetData.swift` — Shared Codable+Sendable data models

## Exported Symbols

- `public struct WidgetData: Codable, Sendable` — Shared widget data container
- `public struct WidgetData.MemberScore: Codable, Sendable` — Per-member score data
- `public let appGroupIdentifier = "group.com.familyscore"` — Single source of truth for App Group
- `extension WidgetData { public static let placeholder }` — For widget previews and snapshots

## Architecture Decisions Honored

- NO Supabase SDK in FamilyScoreKit — only `import Foundation` (widget extension has 30MB limit)
- All public structs are `Sendable` (Swift 6 requirement)
- All public structs have `public init` (required for cross-module initialization)
- `appGroupIdentifier` is the single source of truth — both App and Widget Extension import this constant

## Xcode Integration Required (Manual Step on Mac)

The Xcode integration steps must be performed manually in Xcode on a Mac:
1. File > Add Package Dependencies > Add Local... → select `FamilyScoreKit/` directory
2. FamilyScore App Target → General → Frameworks → `+` → add `FamilyScoreKit`
3. FamilyScoreWidgetExtension Target → General → Frameworks → `+` → add `FamilyScoreKit`
4. Do NOT add Supabase to FamilyScoreKit or FamilyScoreWidgetExtension

## Self-Check

- [x] Package.swift exists with swift-tools-version: 5.9 and iOS 16+ platform
- [x] WidgetData.swift exports WidgetData, MemberScore (both Sendable), appGroupIdentifier, placeholder
- [x] No external dependencies in Package.swift
- [x] Only `import Foundation` in WidgetData.swift (no Supabase, no WidgetKit)
- [x] All public types have public inits
- [ ] Xcode integration pending (requires Xcode on Mac)
- [ ] Build verification pending (requires Xcode on Mac)

## Self-Check: PASSED (file creation complete; Xcode integration and build verification require Mac)
