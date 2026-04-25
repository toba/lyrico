---
# y4d-h0z
title: Make brew install --cask lyrico actually work
status: review
type: bug
priority: high
created_at: 2026-04-25T22:04:01Z
updated_at: 2026-04-25T22:06:19Z
---

## Problem

`brew install --cask toba/homebrew-tap/lyrico` does not work:

- No GitHub releases published (only tags pushed).
- No DMG artifact attached.
- No local release script (sign + notarize + dmg).
- Old release.yml referenced wrong tap repo (`toba/homebrew-lyrico`), should be the shared `toba/homebrew-tap`.
- Tap has no `Casks/` dir or `lyrico.rb`.
- No "Developer ID Application" cert in keychain (only "Apple Development"); no notarytool keychain profile.

## Tasks

- [x] Add `scripts/release.sh` — archive → export → notarize → DMG with sha256
- [x] Update `.github/workflows/release.yml` to push to shared `toba/homebrew-tap` under `Casks/lyrico.rb`
- [x] Seed initial `Casks/lyrico.rb` in `toba/homebrew-tap` (workflow auto-creates on first publish)
- [ ] Document required local credentials (Developer ID cert, notarytool keychain profile)
- [ ] Verify `brew install --cask toba/homebrew-tap/lyrico` end-to-end (requires user creds)



## Summary of Changes

- `scripts/release.sh` — local end-to-end build → sign → notarize → DMG → GitHub release
- `.github/workflows/release.yml` — points at shared `toba/homebrew-tap`, auto-seeds `Casks/lyrico.rb` if missing, no-ops if unchanged
- `README.md` — install command updated to `brew install --cask toba/tap/lyrico`

## Blocked on user action

1. **Create a Developer ID Application certificate** (only "Apple Development" exists in keychain). In Xcode → Settings → Accounts → Manage Certificates → + → "Developer ID Application".
2. **Store notarytool credentials**:
   ```
   xcrun notarytool store-credentials lyrico-notary \\
     --apple-id <your-apple-id> --team-id D6GX9PC3SR \\
     --password <app-specific-password>
   ```
3. **Confirm `HOMEBREW_TAP_TOKEN` secret** is set on `toba/lyrico` (org-level secret may already cover this; first workflow run will tell us).
4. Run `scripts/release.sh 0.3.1` to publish the first real release; the workflow will create `Casks/lyrico.rb` in `toba/homebrew-tap`.

The previously-pushed tags (v0.1.0–v0.3.1) have no GitHub releases attached and are effectively dead — the script will create the release on the existing tag if present.
