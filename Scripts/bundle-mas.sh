#!/usr/bin/env bash
set -euo pipefail

# bundle-mas.sh: Package the KonaAppStore binary into a Mac App Store .app
# bundle at build/mas/Kona.app. Unlike bundle.sh this bundle has no Sparkle
# framework or feed keys — the App Store delivers updates — and it carries the
# metadata App Review requires (category, Apple Events usage description).

if [[ "${KONA_MAS:-0}" != "1" ]]; then
    echo "error: the Mac App Store build is disabled by default (feature flag)." >&2
    echo "       Run with KONA_MAS=1 to build it, e.g.:" >&2
    echo "       KONA_MAS=1 swift build -c release && KONA_MAS=1 bash Scripts/bundle-mas.sh" >&2
    exit 1
fi

APP_NAME="Kona"
PRODUCT="KonaAppStore"
BIN_PATH=$(xcrun swift build -c release --show-bin-path)
BUNDLE_DIR="build/mas/${APP_NAME}.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Determine version
VERSION="${APP_VERSION:-1.0}"
if [[ -z "${APP_VERSION:-}" && -f "VERSION" ]]; then
    VERSION=$(tr -d '[:space:]' < VERSION)
fi

if [[ ! -f "$BIN_PATH/$PRODUCT" ]]; then
    echo "error: $PRODUCT not found in $BIN_PATH; run 'swift build -c release' first" >&2
    exit 1
fi

echo "Creating App Store bundle (version $VERSION)..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Copy executable under the app's name so CFBundleExecutable matches
cp "$BIN_PATH/$PRODUCT" "$MACOS_DIR/$APP_NAME"

# Sanity check: the App Store build must not reference Sparkle
if otool -L "$MACOS_DIR/$APP_NAME" | grep -qi sparkle; then
    echo "error: App Store binary links Sparkle; check target dependencies" >&2
    exit 1
fi

# Copy icon
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# Create Info.plist (no SUFeedURL/SUPublicEDKey: no Sparkle in this build)
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
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Kona asks System Events to put the Mac to sleep when a preset with “Sleep at the end” enabled expires.</string>
    <key>ITSAppUsesNonExemptEncryption</key>
    <false/>
</dict>
</plist>
EOF

# Verify the plist says what App Review expects
PB="/usr/libexec/PlistBuddy"
[[ "$($PB -c 'Print :CFBundleIdentifier' "$CONTENTS_DIR/Info.plist")" == "io.binoio.Kona" ]]
if $PB -c 'Print :SUFeedURL' "$CONTENTS_DIR/Info.plist" >/dev/null 2>&1; then
    echo "error: App Store bundle must not declare a Sparkle feed" >&2
    exit 1
fi

echo "✓ App Store bundle created at: $BUNDLE_DIR"
