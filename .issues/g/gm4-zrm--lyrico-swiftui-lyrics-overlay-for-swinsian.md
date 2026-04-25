---
# gm4-zrm
title: 'Lyrico: SwiftUI lyrics overlay for Swinsian'
status: in-progress
type: feature
priority: high
created_at: 2026-04-25T20:40:15Z
updated_at: 2026-04-25T20:51:55Z
sync:
    github:
        issue_number: "1"
        synced_at: "2026-04-25T20:54:00Z"
---

A native macOS SwiftUI app that shows synced lyrics for the song currently playing in Swinsian. Inspired by [LyricGlow](https://github.com/ateymoori/lyricglow), but pure Swift and tied to Swinsian (not Spotify).

## Goals

- Floating, always-on-top overlay window with karaoke-style synced lyrics
- Auto-detects current Swinsian track + playback position
- Pulls synced LRC lyrics from [LRCLIB](https://lrclib.net) (free, no auth)
- Falls back to embedded lyrics from the track's metadata
- Click-through / pinnable / draggable like a HUD

## Tech sketch

- **Swift 6.3 / SwiftUI**, macOS 26+
- **Track polling**: `ScriptingBridge` against Swinsian's AppleScript dictionary (`current track`, `player position`, `player state`). Poll every ~500ms via a `Timer` on a background actor; debounce track-change events.
- **Lyrics fetch**: `URLSession` async/await against `https://lrclib.net/api/get?artist_name=...&track_name=...&duration=...`. Cache by `(artist, title, duration)` on disk under `~/Library/Caches/Lyrico/`.
- **LRC parser**: parse `[mm:ss.xx] line` timestamps into `[(TimeInterval, String)]`.
- **Sync engine**: tick at 30 Hz, find active line via binary search over timestamps, advance highlight with smooth `.animation(.easeInOut)`.
- **Window**: `Window` with `.windowStyle(.hiddenTitleBar)` + `.windowLevel(.floating)`, or a borderless `NSPanel` wrapped via `NSViewControllerRepresentable`. Liquid Glass background where available.
- **State**: `@Observable` `LyricsEngine` exposing `currentLine`, `nextLine`, `progress`. View reads via `@Environment`.

## Tasks

- [x] Scaffold SwiftUI macOS app (`xc-mcp scaffold_macos_project`)
- [ ] `SwinsianClient` — ScriptingBridge wrapper around Swinsian's `.sdef`
- [x] `LRCLIBClient` — async API client with on-disk response cache
- [x] `LRCParser` — parse synced + plain LRC, return `[LyricLine]`
- [x] `LyricsEngine` — `@Observable`, snapshot-driven active-line state (polling driver lives in app target)
- [ ] `OverlayWindow` — floating panel, draggable, pin toggle, opacity slider
- [ ] `LyricsView` — current line large, prev/next dimmed, smooth scroll
- [ ] Settings: font size, color, opacity, hotkey to toggle visibility
- [ ] Menu bar icon (`MenuBarExtra`) for show/hide + preferences
- [ ] README with screenshot, install instructions, attribution to LRCLIB

## Open questions

- Use `ScriptingBridge` (typed) or `NSAppleScript` (string-based)? SB is faster but needs the generated header from `sdef Swinsian.app | sdp -fh --basename Swinsian`.
- For frame-accurate sync: stick with AppleScript polling (~100ms drift) or read private `MediaRemote.framework`? Start with AppleScript — good enough.
- Distribute via Homebrew cask? Probably yes.

## References

- LyricGlow (Spotify-based): https://github.com/ateymoori/lyricglow
- LRCLIB API: https://lrclib.net/docs
- Swinsian AppleScript dictionary: open in Script Editor → File → Open Dictionary → Swinsian
