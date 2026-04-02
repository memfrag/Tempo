#!/bin/bash
set -euo pipefail

error() {
    echo "ERROR: $1" >&2
    exit 1
}

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
PBXPROJ="$PROJECT_DIR/Tempo.xcodeproj/project.pbxproj"
INFO_PLIST="$PROJECT_DIR/Sources/Resources/Info.plist"

# ── Clean and create build directory ─────────────────────────────────────────
echo "==> Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# ── Download Sparkle tools if needed ─────────────────────────────────────────
if [ ! -x "$SPARKLE_TOOLS_DIR/bin/sign_update" ]; then
    echo "==> Downloading Sparkle tools v$SPARKLE_VERSION..."
    curl -sL "https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz" -o "$BUILD_DIR/Sparkle.tar.xz" \
        || error "Failed to download Sparkle tools"
    mkdir -p "$SPARKLE_TOOLS_DIR"
    tar -xf "$BUILD_DIR/Sparkle.tar.xz" -C "$SPARKLE_TOOLS_DIR" \
        || error "Failed to extract Sparkle tools"
    rm "$BUILD_DIR/Sparkle.tar.xz"
    echo "    Sparkle tools installed at $SPARKLE_TOOLS_DIR"
fi

# ── Version management ───────────────────────────────────────────────────────
echo "==> Checking version..."

CURRENT_VERSION=""

# Try MARKETING_VERSION from build settings first
BUILD_SETTINGS=$(xcodebuild -scheme "$SCHEME" -showBuildSettings 2>/dev/null || true)
if [ -n "$BUILD_SETTINGS" ]; then
    CURRENT_VERSION=$(echo "$BUILD_SETTINGS" | grep "MARKETING_VERSION" | head -1 | awk '{print $NF}' || true)
fi

# Fall back to Info.plist
if [ -z "$CURRENT_VERSION" ]; then
    CURRENT_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null || true)
fi

if [ -z "$CURRENT_VERSION" ]; then
    error "Could not determine current version from build settings or Info.plist"
fi

echo "    Current version: $CURRENT_VERSION"

LATEST_TAG=$(gh release view --repo "$GITHUB_REPO" --json tagName -q '.tagName' 2>/dev/null || echo "none")
echo "    Latest GitHub release: $LATEST_TAG"

read -rp "    Enter new version (leave empty to keep $CURRENT_VERSION): " NEW_VERSION

if [ -n "$NEW_VERSION" ]; then
    VERSION="$NEW_VERSION"
    if grep -q "MARKETING_VERSION" "$PBXPROJ"; then
        echo "    Updating version to $VERSION in project.pbxproj..."
        sed -i '' "s/MARKETING_VERSION = [^;]*/MARKETING_VERSION = $VERSION/" "$PBXPROJ"
        sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*/CURRENT_PROJECT_VERSION = $VERSION/" "$PBXPROJ"
    fi
    echo "    Updating version to $VERSION in Info.plist..."
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$INFO_PLIST" \
        || error "Failed to update CFBundleShortVersionString in Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$INFO_PLIST" \
        || error "Failed to update CFBundleVersion in Info.plist"
    cd "$PROJECT_DIR"
    git add -A
    git commit -m "Bump version to $VERSION"
    git push origin HEAD
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
    2>&1 | tee "$BUILD_DIR/archive.log" | tail -5

if [ ! -d "$ARCHIVE_PATH" ]; then
    echo ""
    echo "    Archive log (last 30 lines):"
    tail -30 "$BUILD_DIR/archive.log"
    error "Archive failed. See $BUILD_DIR/archive.log for full output."
fi

# ── Export ───────────────────────────────────────────────────────────────────
echo "==> Exporting..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    2>&1 | tee "$BUILD_DIR/export.log" | tail -5

APP_PATH="$EXPORT_DIR/$APP_NAME.app"

if [ ! -d "$APP_PATH" ]; then
    echo ""
    echo "    Export log (last 30 lines):"
    tail -30 "$BUILD_DIR/export.log"
    error "Export failed. See $BUILD_DIR/export.log for full output."
fi

# ── Extract version from exported app ────────────────────────────────────────
EXPORTED_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist") \
    || error "Failed to read version from exported app"
echo "    Exported app version: $EXPORTED_VERSION"

# ── Create DMG ───────────────────────────────────────────────────────────────
echo "==> Creating DMG..."
DMG_NAME="$APP_NAME-$VERSION.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"
DMG_STAGING="$BUILD_DIR/dmg-staging"

mkdir -p "$DMG_STAGING"
cp -a "$APP_PATH" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_STAGING" -ov -format UDZO "$DMG_PATH" \
    || error "Failed to create DMG"
rm -rf "$DMG_STAGING"

echo "    DMG created at $DMG_PATH"

# ── Verify codesign ─────────────────────────────────────────────────────────
echo "==> Verifying codesign..."
codesign --verify --deep --strict "$APP_PATH" \
    || error "Codesign verification failed"
echo "    Codesign verified."

# ── Notarize ─────────────────────────────────────────────────────────────────
echo "==> Submitting DMG for notarization..."
xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait \
    || error "Notarization failed"

echo "==> Stapling..."
xcrun stapler staple "$DMG_PATH" \
    || error "Stapling failed"
echo "    Notarization complete."

# ── Sign for Sparkle ─────────────────────────────────────────────────────────
echo "==> Signing for Sparkle..."
SPARKLE_SIG=$("$SPARKLE_TOOLS_DIR/bin/sign_update" "$DMG_PATH") \
    || error "Sparkle signing failed"
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
git tag "$TAG" || error "Failed to create tag $TAG"
git push origin "$TAG" || error "Failed to push tag $TAG"

RELEASE_BODY="$RELEASE_TITLE"
if [ -n "$RELEASE_SUBTITLE" ]; then
    RELEASE_BODY="$RELEASE_TITLE -- $RELEASE_SUBTITLE"
fi

gh release create "$TAG" "$DMG_PATH" \
    --repo "$GITHUB_REPO" \
    --title "$RELEASE_BODY" \
    --generate-notes \
    || error "Failed to create GitHub release"

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
    "$APPCAST_DIR" \
    || error "Failed to generate appcast"

cp "$APPCAST_DIR/appcast.xml" "$PROJECT_DIR/appcast.xml"
cd "$PROJECT_DIR"
git add appcast.xml
git commit -m "Update appcast for $VERSION"
git push origin HEAD

echo ""
echo "==> Done! Tempo $VERSION has been built, notarized, and released."
echo "    GitHub: https://github.com/$GITHUB_REPO/releases/tag/$TAG"
echo "    DMG:    $DMG_PATH"
