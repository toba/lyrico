---
# 70s-953
title: App stuck on 'Waiting for Swinsian…' even when Swinsian is running
status: completed
type: bug
priority: high
created_at: 2026-04-25T23:42:22Z
updated_at: 2026-04-25T23:57:46Z
parent: gm4-zrm
sync:
    github:
        issue_number: "4"
        synced_at: "2026-04-25T23:58:31Z"
---

## Symptom

After installing Lyrico (e.g. via `brew install --cask toba/tap/lyrico`) and launching it while Swinsian is running and playing a track, the app remains stuck on the idle status text "Waiting for Swinsian…" indefinitely. Lyrics never load.

## Suspected Causes

The Swinsian AppleScript bridge (`Sources/LyricoKit/SwinsianClient.swift`) is likely failing silently:

- The script first checks `tell application "System Events" ... if not (exists process "Swinsian")` and returns `""` if false. Inside the App Sandbox, talking to System Events requires an Apple Events authorization that may not have been granted, which can cause the script to fail or return empty.
- `SwinsianClient.parseResponse` treats empty / unrecognized output as `nil`, which the engine maps to `.idle` ("Waiting for Swinsian…"), so the user sees no error.
- The first AppleScript send normally triggers the macOS automation consent prompt ("Lyrico wants to control Swinsian"). If that prompt was dismissed, denied, or never shown (e.g. on a release build with different signing), subsequent calls fail with errAEEventNotPermitted (-1743) and we silently fall through to idle.
- Sandbox entitlements only list `com.swinsian.Swinsian` as a scripting target — not `com.apple.systemevents`. The `tell application "System Events"` block at the top of the script may be rejected outright in the sandbox.

## Reproduction

1. `brew install --cask toba/tap/lyrico`
2. Launch Swinsian and start playing a track
3. Launch Lyrico
4. Observe: window shows "Waiting for Swinsian…" and never advances

## Acceptance

- [x] Add a failing test that reproduces the silent-failure path (e.g. AppleScript error → engine should surface `.error` instead of staying `.idle`)
- [x] Surface AppleScript errors to the UI (`LyricsEngine.Status.error`) instead of swallowing them as nil
- [x] Verify automation consent: confirm Swinsian appears under System Settings → Privacy & Security → Automation for Lyrico, and that the script actually returns a snapshot
- [x] Remove the `tell application "System Events"` preflight (no longer needed; sandbox is gone)
- [x] Manually verify by build+launch+screenshot — lyrics appear
- [ ] (deferred) Document in README how to reset automation permissions (`tccutil reset AppleEvents app.toba.lyrico`) for users who hit a denied prompt

## Related

- Parent feature: gm4-zrm (Lyrico: SwiftUI lyrics overlay for Swinsian)



## Summary of Changes

The app was non-functional for three independent reasons, all now fixed:

1. **Wrong AppleScript property** (`Sources/LyricoKit/SwinsianClient.swift`) — the script used `persistent ID of t`, which is iTunes/Music.app terminology. Swinsian's track has `id`, not `persistent ID`, so AppleScript failed to compile with error -2741. Changed to `id of t as text`.

2. **App Sandbox blocked Apple Events to Swinsian** (`Xcode/Lyrico/Lyrico.entitlements`) — Swinsian doesn't declare an `NSScriptingAccessGroup`, so `com.apple.security.scripting-targets` with group `com.swinsian.scripting` produced "privilege violation" errors from Swinsian. Removed `app-sandbox` and `scripting-targets`; kept `automation.apple-events` for TCC consent and `network.client` for LRCLIB. The app is distributed via Homebrew cask (Developer-ID signed + notarized), not the Mac App Store, so sandbox is not required.

3. **Silent failure path** (`Sources/LyricoKit/LyricsPoller.swift`, `LyricsEngine.swift`) — `LyricsPoller.tick` was swallowing source errors and posting `nil` snapshots, which collapsed to `.idle` ("Waiting for Swinsian…") regardless of the underlying cause. Added `LyricsEngine.reportSourceError(_:)` and route thrown errors to `.error(message)` so future regressions surface visibly. Updated the `LyricsPollerTests` test that documented the old swallow behavior to assert the new surfacing behavior (failing-test-first, then green).

Also removed the now-unneeded `tell application "System Events"` preflight from the AppleScript and dropped `.treatAllWarnings(as: .error)` from `Package.swift` because Xcode 26 appends `-suppress-warnings` to package builds, conflicting with `-warnings-as-errors`. The Xcode app target still has `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES`.

Verified end-to-end: built the app, launched it while Swinsian was playing Rammstein – Mein Teil, captured a screenshot showing the live synced lyrics rendered.

All 53 SPM tests pass.
