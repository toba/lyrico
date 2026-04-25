# Lyrico

A macOS app.

## Important Agent Rules

- When working on errors, always create a failing test first then fix the issue and confirm the test passes
- **Jig issue tracking is mandatory for all work:**
  - Check for an existing jig issue before starting. If none exists, create one with `jig todo create`
  - Set the issue to `in-progress` when you begin work
  - Update the issue body continuously as you complete checklist items (check off `- [ ]` → `- [x]`)
  - Add new checklist items to the issue when scope evolves during work
  - When done, set status to `completed` (or `review` if user action needed)
  - Include issue file(s) in commits
- Never git stash to avoid an error — FIX the error

## Project Structure

SPM package at the root with a library target, Xcode project in `Xcode/` for the macOS app.

- `Package.swift` — SPM package defining `LyricoKit` library
- `Sources/LyricoKit/` — Core library
- `Tests/LyricoKitTests/` — Unit tests for the library (swift-testing)
- `Xcode/Lyrico.xcodeproj` — macOS app project (references LyricoKit as local SPM dependency)
- `Xcode/Lyrico/` — SwiftUI app code (views, app entry point)

## Swift & Build Settings

- swift-tools-version: 6.3
- macOS 26+ only (no iOS, no Catalyst)
- Xcode 26.4+
- Swift 6 language mode with strict concurrency complete
- Warnings treated as errors
- Upcoming features enabled: `ExistentialAny`, `InternalImportsByDefault`, `MemberImportVisibility`, `InferIsolatedConformances`, `NonisolatedNonsendingByDefault`
- Experimental features enabled: `StrictMemorySafety`
- Uses `@Observable` (Observation framework), not Combine
- Prefer `swift-testing` (`@Test`/`#expect`) over XCTest for new tests
