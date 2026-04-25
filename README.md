# Lyrico

Floating synced-lyrics overlay for [Swinsian](https://swinsian.com) on macOS.

Lyrico watches the currently playing track in Swinsian, fetches synced lyrics
from [LRCLIB](https://lrclib.net), and displays them in a translucent
always-on-top window.

## Install

```sh
brew install --cask toba/lyrico/lyrico
```

Requires macOS 26 (Tahoe) or later.

## Develop

The repo is a Swift Package at the root with the macOS app target under
`Xcode/`. Open the Xcode project to build and run; tests use
[swift-testing](https://github.com/apple/swift-testing).
