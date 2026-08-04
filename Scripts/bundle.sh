#!/usr/bin/env bash
set -euo pipefail

# bundle.sh: Package the built Kona binary into a macOS .app bundle

APP_NAME="Kona"
# Detect bin path from swift build
BIN_PATH=$(xcrun swift build -c release --show-bin-path)
BUILD_DIR="${BIN_PATH}"
BUNDLE_DIR="build/${APP_NAME}.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Determine version
VERSION="${APP_VERSION:-1.0}"
if [[ -z "${APP_VERSION:-}" && -f "VERSION" ]]; then
    VERSION=$(tr -d '[:space:]' < VERSION)
fi

# Sparkle update feed and EdDSA public key (env-overridable for testing)
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-https://binoio.github.io/kona/appcast.xml}"
SPARKLE_ED_PUBLIC_KEY="${SPARKLE_ED_PUBLIC_KEY:-nDAE5HXFYg6pBQbAFtyEObXbHu9N7TM+7zUivRcRqNA=}"

echo "Creating app bundle (version $VERSION)..."
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Copy executable
cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"

# Embed Sparkle.framework (the executable links it via @rpath/../Frameworks)
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
SPARKLE_FRAMEWORK=$(find .build -type d -name "Sparkle.framework" -path "*artifacts*" -not -path "*dSYM*" | head -1)
if [[ -z "$SPARKLE_FRAMEWORK" ]]; then
    echo "error: Sparkle.framework not found under .build; run 'swift build' first" >&2
    exit 1
fi
mkdir -p "$FRAMEWORKS_DIR"
rm -rf "$FRAMEWORKS_DIR/Sparkle.framework"
# ditto preserves the framework's Versions symlink structure; cp -R would not
ditto "$SPARKLE_FRAMEWORK" "$FRAMEWORKS_DIR/Sparkle.framework"

# Copy icon
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# Create Info.plist
cat > "$CONTENTS_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Kona</string>
    <key>CFBundleIdentifier</key>
    <string>io.binoio.Kona</string>
    <key>CFBundleName</key>
    <string>Kona</string>
    <key>CFBundleDisplayName</key>
    <string>Kona</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>SUFeedURL</key>
    <string>$SPARKLE_FEED_URL</string>
    <key>SUPublicEDKey</key>
    <string>$SPARKLE_ED_PUBLIC_KEY</string>
</dict>
</plist>
EOF

echo "✓ App bundle created at: $BUNDLE_DIR"
