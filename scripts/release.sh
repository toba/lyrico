#!/usr/bin/env bash
# Build, sign, notarize, and package Lyrico into a distributable DMG, then
# create a GitHub release with the DMG attached. The `release` workflow in
# .github/workflows/release.yml fires on `release: published` and bumps the
# Homebrew cask in toba/homebrew-tap.
#
# Required local setup:
#   - "Developer ID Application: <Name> (<TeamID>)" cert in your login keychain
#   - notarytool keychain profile named "lyrico-notary":
#       xcrun notarytool store-credentials lyrico-notary \
#         --apple-id <appleid> --team-id <teamid> --password <app-specific-pw>
#   - gh CLI authenticated with repo write access
#
# Usage: scripts/release.sh <version>   (e.g. scripts/release.sh 0.3.1)
set -euo pipefail

VERSION="${1:?usage: scripts/release.sh <version>}"
TAG="v$VERSION"
PROJECT="Xcode/Lyrico.${PROJ_EXT:-xcodeproj}"
SCHEME="Lyrico"
TEAM_ID="${TEAM_ID:-D6GX9PC3SR}"
NOTARY_PROFILE="${NOTARY_PROFILE:-lyrico-notary}"
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application}"

BUILD_DIR="$(pwd)/build/release"
ARCHIVE="$BUILD_DIR/Lyrico.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
DMG_DIR="$BUILD_DIR/dmg"
DMG_NAME="Lyrico-$VERSION.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"
EXPORT_PLIST="$BUILD_DIR/ExportOptions.plist"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$DMG_DIR"

cat > "$EXPORT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
</dict></plist>
PLIST

echo "==> Archiving (Release, Developer ID signing)"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE" \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$VERSION" \
  CODE_SIGN_STYLE=Automatic \
  CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime" \
  archive

echo "==> Exporting .app"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$EXPORT_PLIST" \
  -exportPath "$EXPORT_DIR"

APP_PATH="$EXPORT_DIR/Lyrico.app"
[[ -d "$APP_PATH" ]] || { echo "Lyrico.app not found at $APP_PATH"; exit 1; }

echo "==> Building DMG"
cp -R "$APP_PATH" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"
hdiutil create -volname "Lyrico" -srcfolder "$DMG_DIR" -ov -format UDZO "$DMG_PATH"

echo "==> Signing DMG"
codesign --sign "$SIGN_IDENTITY" --timestamp "$DMG_PATH"

echo "==> Notarizing DMG (this can take a few minutes)"
xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

echo "==> Stapling notarization ticket"
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

SHA256="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
echo "==> $DMG_NAME  sha256=$SHA256"

if ! git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "==> Creating tag $TAG"
  git tag "$TAG"
  git push origin "$TAG"
fi

echo "==> Publishing GitHub release $TAG"
if gh release view "$TAG" >/dev/null 2>&1; then
  gh release upload "$TAG" "$DMG_PATH" --clobber
else
  gh release create "$TAG" "$DMG_PATH" \
    --title "Lyrico $VERSION" \
    --notes "Lyrico $VERSION

sha256: \`$SHA256\`"
fi

echo "==> Done. The 'release' workflow will bump the cask in toba/homebrew-tap."
