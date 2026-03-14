#!/bin/bash

# Build script for Kona

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Building Kona..."

swift build --configuration release

echo "Build complete."

# Create app bundle
APP_NAME="Kona"
BUILD_DIR=".build/arm64-apple-macosx/release"
BUNDLE_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

if [ ! -d "$BUNDLE_DIR" ]; then
    echo "Creating app bundle..."
    
    mkdir -p "$MACOS_DIR"
    mkdir -p "$RESOURCES_DIR"
    
    # Copy executable
    cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
    
    # Copy icon
    if [ -f "$PROJECT_DIR/Resources/AppIcon.icns" ]; then
        cp "$PROJECT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
    fi
    
    # Create Info.plist
    cat > "$CONTENTS_DIR/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Kona</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.Kona</string>
    <key>CFBundleName</key>
    <string>Kona</string>
    <key>CFBundleDisplayName</key>
    <string>Kona</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
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
</dict>
</plist>
EOF
    
    echo "App bundle created at: $BUNDLE_DIR"
else
    # Update executable in existing bundle
    cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
    
    # Update icon if needed
    if [ -f "$PROJECT_DIR/Resources/AppIcon.icns" ]; then
        mkdir -p "$RESOURCES_DIR"
        cp "$PROJECT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
    fi
    
    echo "App bundle updated at: $BUNDLE_DIR"
fi