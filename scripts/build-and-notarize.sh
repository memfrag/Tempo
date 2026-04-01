#!/bin/bash
set -euo pipefail

# ── Constants ────────────────────────────────────────────────────────────────
SCHEME="Tempo"
APP_NAME="Tempo"
KEYCHAIN_PROFILE="notary"
SPARKLE_VERSION="2.9.0"
GITHUB_REPO="memfrag/Tempo"

# ── Paths ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
SPARKLE_TOOLS_DIR="$PROJECT_DIR/Sparkle-tools"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
EXPORT_OPTIONS="$SCRIPT_DIR/ExportOptions.plist"

# ── Clean and create build directory ─────────────────────────────────────────
echo "==> Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# ── Download Sparkle tools if needed ─────────────────────────────────────────
if [ ! -x "$SPARKLE_TOOLS_DIR/bin/sign_update" ]; then
    echo "==> Downloading Sparkle tools v$SPARKLE_VERSION..."
    curl -sL "https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz" -o "$BUILD_DIR/Sparkle.tar.xz"
    mkdir -p "$SPARKLE_TOOLS_DIR"
    tar -xf "$BUILD_DIR/Sparkle.tar.xz" -C "$SPARKLE_TOOLS_DIR"
    rm "$BUILD_DIR/Sparkle.tar.xz"
    echo "    Sparkle tools installed at $SPARKLE_TOOLS_DIR"
fi

# ── Version management ───────────────────────────────────────────────────────
echo "==> Checking version..."

CURRENT_VERSION=$(xcodebuild -scheme "$SCHEME" -showBuildSettings 2>/dev/null \
    | grep "MARKETING_VERSION" | head -1 | awk '{print $NF}')

if [ -z "$CURRENT_VERSION" ]; then
    CURRENT_VERSION="0.0.0"
fi

echo "    Current version: $CURRENT_VERSION"

LATEST_TAG=$(gh release view --repo "$GITHUB_REPO" --json tagName -q '.tagName' 2>/dev/null || echo "none")
echo "    Latest GitHub release: $LATEST_TAG"

read -rp "    Enter new version (leave empty to keep $CURRENT_VERSION): " NEW_VERSION

if [ -n "$NEW_VERSION" ]; then
    VERSION="$NEW_VERSION"
    echo "    Updating version to $VERSION in project.pbxproj..."
    sed -i '' "s/MARKETING_VERSION = [^;]*/MARKETING_VERSION = $VERSION/" "$PROJECT_DIR/Tempo.xcodeproj/project.pbxproj"
    sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*/CURRENT_PROJECT_VERSION = $VERSION/" "$PROJECT_DIR/Tempo.xcodeproj/project.pbxproj"
    cd "$PROJECT_DIR"
    git add Tempo.xcodeproj/project.pbxproj
    git commit -m "Bump version to $VERSION"
    git push origin HEAD
    cd "$SCRIPT_DIR"
else
    VERSION="$CURRENT_VERSION"
fi

echo "    Building version: $VERSION"

# ── Archive ──────────────────────────────────────────────────────────────────
echo "==> Archiving..."
xcodebuild archive \
    -project "$PROJECT_DIR/$APP_NAME.xcodeproj" \
    -scheme "$SCHEME" \
    -archivePath "$ARCHIVE_PATH" \
    -configuration Release \
    -arch arm64 \
    ENABLE_HARDENED_RUNTIME=YES \
    | tail -1

# ── Export ───────────────────────────────────────────────────────────────────
echo "==> Exporting..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    | tail -1

# ── Extract version from exported app ────────────────────────────────────────
APP_PATH="$EXPORT_DIR/$APP_NAME.app"
EXPORTED_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
echo "    Exported app version: $EXPORTED_VERSION"

# ── Create DMG ───────────────────────────────────────────────────────────────
echo "==> Creating DMG..."
DMG_NAME="$APP_NAME-$VERSION.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"
DMG_STAGING="$BUILD_DIR/dmg-staging"

mkdir -p "$DMG_STAGING"
cp -a "$APP_PATH" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_STAGING" -ov -format UDZO "$DMG_PATH"
rm -rf "$DMG_STAGING"

echo "    DMG created at $DMG_PATH"

# ── Verify codesign ─────────────────────────────────────────────────────────
echo "==> Verifying codesign..."
codesign --verify --deep --strict "$APP_PATH"
echo "    Codesign verified."

# ── Notarize ─────────────────────────────────────────────────────────────────
echo "==> Submitting DMG for notarization..."
xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait

echo "==> Stapling..."
xcrun stapler staple "$DMG_PATH"
echo "    Notarization complete."

# ── Sign for Sparkle ─────────────────────────────────────────────────────────
echo "==> Signing for Sparkle..."
SPARKLE_SIG=$("$SPARKLE_TOOLS_DIR/bin/sign_update" "$DMG_PATH")
echo "    Sparkle signature:"
echo "    $SPARKLE_SIG"

# ── Create GitHub release ────────────────────────────────────────────────────
TAG="$VERSION"

read -rp "    Enter release title (leave empty for 'Tempo $VERSION'): " RELEASE_TITLE
if [ -z "$RELEASE_TITLE" ]; then
    RELEASE_TITLE="Tempo $VERSION"
fi

read -rp "    Enter release subtitle (optional, leave empty to skip): " RELEASE_SUBTITLE

echo "==> Creating GitHub release $TAG..."
cd "$PROJECT_DIR"
git tag "$TAG"
git push origin "$TAG"

RELEASE_BODY="$RELEASE_TITLE"
if [ -n "$RELEASE_SUBTITLE" ]; then
    RELEASE_BODY="$RELEASE_TITLE -- $RELEASE_SUBTITLE"
fi

gh release create "$TAG" "$DMG_PATH" \
    --repo "$GITHUB_REPO" \
    --title "$RELEASE_BODY" \
    --generate-notes

echo "    Release created: https://github.com/$GITHUB_REPO/releases/tag/$TAG"

# ── Generate appcast ─────────────────────────────────────────────────────────
echo "==> Generating appcast..."
APPCAST_DIR="$BUILD_DIR/appcast-assets"
mkdir -p "$APPCAST_DIR"

if [ -f "$PROJECT_DIR/appcast.xml" ]; then
    cp "$PROJECT_DIR/appcast.xml" "$APPCAST_DIR/"
fi

cp "$DMG_PATH" "$APPCAST_DIR/"

"$SPARKLE_TOOLS_DIR/bin/generate_appcast" \
    --download-url-prefix "https://github.com/$GITHUB_REPO/releases/download/$TAG/" \
    -o "$APPCAST_DIR/appcast.xml" \
    "$APPCAST_DIR"

cp "$APPCAST_DIR/appcast.xml" "$PROJECT_DIR/appcast.xml"
cd "$PROJECT_DIR"
git add appcast.xml
git commit -m "Update appcast for $VERSION"
git push origin HEAD

echo ""
echo "==> Done! Tempo $VERSION has been built, notarized, and released."
echo "    GitHub: https://github.com/$GITHUB_REPO/releases/tag/$TAG"
echo "    DMG:    $DMG_PATH"
