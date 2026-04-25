---
# c6x-ugx
title: Distribute Lyrico via Homebrew cask
status: review
type: feature
priority: normal
created_at: 2026-04-25T21:05:50Z
updated_at: 2026-04-25T21:46:01Z
sync:
    github:
        issue_number: "2"
        synced_at: "2026-04-25T21:46:33Z"
---

## Goal

Let users install Lyrico with a single command:

```
brew install --cask toba/lyrico/lyrico
```

## Why a cask, not a formula

Lyrico is a SwiftUI `.app` bundle, not a CLI binary. Homebrew distributes GUI apps via **casks** (`brew install --cask`) rather than formulas. The `/brew` skill in this repo is built for goreleaser-style CLI tools and would generate a broken formula (`bin.install`, `tool version` test) if used as-is.

## Prerequisites

These must be in place before the cask can work:

- [x] **Release pipeline**: `.github/workflows/release.yml` that on tag push:
  - [x] Builds `Lyrico.app` for arm64
  - [x] Code-signs with a Developer ID Application certificate
  - [x] Notarizes with Apple's notary service and staples the ticket
  - [x] Packages as a `.dmg`
  - [x] Uploads the artifact + a `.sha256` to the GitHub Release
- [ ] **Secrets** in the source repo:
  - [ ] `MACOS_CERTIFICATE` (base64 .p12), `MACOS_CERTIFICATE_PASSWORD`
  - [ ] `AC_API_KEY_ID`, `AC_API_KEY_ISSUER_ID`, `AC_API_KEY` (for notarization via App Store Connect API)
  - [ ] `HOMEBREW_TAP_TOKEN` (fine-grained PAT with Contents read/write on the tap repo)
- [x] **Tap repo**: `toba/homebrew-lyrico` created on GitHub with a `Casks/` directory
- [ ] **`companions.brew`** in `.jig.yaml`: `toba/homebrew-lyrico` (kept for parity with other toba projects, even though the skill itself doesn't manage casks)

## Cask file

The skill doesn't generate casks — write `Casks/lyrico.rb` by hand, roughly:

```ruby
cask "lyrico" do
  version "0.2.0"
  sha256 "…"

  url "https://github.com/toba/lyrico/releases/download/v#{version}/Lyrico-#{version}.dmg"
  name "Lyrico"
  desc "Floating synced-lyrics overlay for Swinsian"
  homepage "https://github.com/toba/lyrico"

  depends_on macos: ">= :tahoe"  # macOS 26+

  app "Lyrico.app"

  zap trash: [
    "~/Library/Caches/Lyrico",
    "~/Library/Preferences/app.toba.lyrico.plist",
  ]
end
```

## CI step to update the cask

After the release artifact is uploaded, a job should:
1. Compute `sha256` of the `.dmg`
2. Clone `toba/homebrew-lyrico`
3. Rewrite `Casks/lyrico.rb` with the new version + sha256
4. Commit + push using `HOMEBREW_TAP_TOKEN`

## Acceptance criteria

- [ ] Pushing a tag to `toba/lyrico` produces a notarized, stapled `.dmg` on the release
- [ ] The same workflow updates `Casks/lyrico.rb` in `toba/homebrew-lyrico` with matching version + sha256
- [ ] `brew tap toba/lyrico && brew install --cask lyrico` installs and launches the app without Gatekeeper warnings
- [ ] `brew uninstall --cask lyrico --zap` cleans up caches and prefs
- [x] README documents the install command

## Out of scope

- Auto-update inside the app (Sparkle / built-in updater) — separate issue
- Upstreaming to homebrew-cask (the official tap) — only sensible after the project is stable and popular enough to meet their inclusion criteria

## Related

- Earlier conversation: `/brew` skill flagged as CLI-only; opted to defer until release pipeline exists


## Distribution model

User signs + notarizes the `.dmg` **locally** (with their Developer ID) and uploads it to a GitHub Release. CI does the cask bump only — no signing secrets needed.

## In-tree

- Shared scheme `Lyrico` added under the Xcode project so `xcodebuild -scheme Lyrico` works
- `.github/workflows/release.yml` — fires on `release: published`, downloads the user-uploaded `Lyrico-X.Y.Z.dmg`, computes sha256, rewrites `Casks/lyrico.rb` in `toba/homebrew-lyrico`
- `README.md` — documents `brew install --cask toba/lyrico/lyrico`

## Required secrets

- [x] `HOMEBREW_TAP_TOKEN` (fine-grained PAT, Contents read/write on `toba/homebrew-lyrico`) — ready

## Per-release flow

1. Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in the Xcode project
2. Archive in Xcode (Developer ID, manual signing)
3. Notarize + staple locally (`xcrun notarytool submit … --wait && xcrun stapler staple`)
4. Package as `Lyrico-X.Y.Z.dmg`
5. `gh release create vX.Y.Z Lyrico-X.Y.Z.dmg --generate-notes`
6. CI fires, bumps the cask

## Still required before first release

- [ ] Out-of-tree: create initial `Casks/lyrico.rb` in `toba/homebrew-lyrico` (placeholder `version` + `sha256` — CI overwrites). Use `depends_on macos: ">= :tahoe"`.
- [ ] Cut `v0.x.y` end-to-end and confirm the cask bump lands
