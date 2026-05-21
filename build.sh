#!/bin/bash
set -e

echo "=== Building OverflowPeek ==="

# Generate Xcode project
xcodegen generate

# Clean and build Release
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
    -project OverflowPeek.xcodeproj \
    -scheme OverflowPeek \
    -configuration Release \
    build

# Find and copy the built app
BUILT_APP=$(find ~/Library/Developer/Xcode/DerivedData -name "OverflowPeek.app" -type d -maxdepth 4 2>/dev/null | head -1)
if [ -z "$BUILT_APP" ]; then
    echo "ERROR: Could not find built app"
    exit 1
fi

echo "Copying from: $BUILT_APP"
rm -rf ./OverflowPeek.app
cp -R "$BUILT_APP" ./

# Clean extended attributes and re-sign
echo "Stripping extended attributes..."
xattr -cr ./OverflowPeek.app

echo "Re-signing with ad-hoc signature..."
codesign --force --deep --sign - ./OverflowPeek.app

echo "=== Build complete: ./OverflowPeek.app ==="
echo "Run: open ./OverflowPeek.app"
