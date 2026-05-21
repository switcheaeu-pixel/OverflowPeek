#!/bin/bash

# Overflow Peek - Build Script
# Creates a macOS .app bundle from Swift Package

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔═══════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Overflow Peek - Build & Package    ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════╝${NC}"
echo ""

# Configuration
APP_NAME="OverflowPeek"
BUNDLE_ID="com.local.OverflowPeek"
VERSION="1.0.0"
BUILD_NUMBER="1"
MIN_MACOS="13.0"

echo -e "${YELLOW}→${NC} Building release version..."
swift build -c release

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Build failed!${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Build successful!${NC}"
echo ""
echo -e "${YELLOW}→${NC} Creating app bundle..."

# Remove old app if exists
rm -rf "${APP_NAME}.app"

# Create app structure
mkdir -p "${APP_NAME}.app/Contents/MacOS"
mkdir -p "${APP_NAME}.app/Contents/Resources"

# Copy executable
cp ".build/release/${APP_NAME}" "${APP_NAME}.app/Contents/MacOS/"

# Make executable
chmod +x "${APP_NAME}.app/Contents/MacOS/${APP_NAME}"

# Create Info.plist
cat > "${APP_NAME}.app/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Overflow Peek</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key>
    <string>${MIN_MACOS}</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026. All rights reserved.</string>
</dict>
</plist>
EOF

echo -e "${GREEN}✓ App bundle created!${NC}"
echo ""
echo -e "${BLUE}═════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Build Complete!${NC}"
echo -e "${BLUE}═════════════════════════════════════════${NC}"
echo ""
echo "📦 App location: $(pwd)/${APP_NAME}.app"
echo "📏 App size: $(du -sh "${APP_NAME}.app" | cut -f1)"
echo ""
echo "To run:      ${YELLOW}open ${APP_NAME}.app${NC}"
echo "To install:  ${YELLOW}cp -r ${APP_NAME}.app /Applications/${NC}"
echo "To test:     ${YELLOW}open -a ${APP_NAME}${NC}"
echo ""

# Optional: Ask if user wants to open the app
read -p "Do you want to open the app now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}→${NC} Opening ${APP_NAME}..."
    open "${APP_NAME}.app"
fi
