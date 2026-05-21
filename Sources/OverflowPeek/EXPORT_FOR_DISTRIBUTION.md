# How to Export Overflow Peek for Distribution

## Problem
When archiving a Swift Package executable, Xcode doesn't show the normal "Distribute App" options because SPM projects aren't configured the same way as traditional Xcode projects.

## Solutions

---

## ✅ **Option 1: Convert to Xcode Project (RECOMMENDED)**

This gives you the full macOS app experience with proper icons, notarization, and distribution.

### Steps:

1. **Create a new macOS App in Xcode**
   - File → New → Project
   - Choose **macOS** → **App**
   - Name it "OverflowPeek"
   - Use SwiftUI interface
   - Save it in a new folder (not your current project)

2. **Copy your source files**
   - Drag all `.swift` files from `Sources/OverflowPeek/` to the new Xcode project
   - Make sure "Copy items if needed" is checked

3. **Configure the app**
   - Set Bundle Identifier (e.g., `com.yourname.OverflowPeek`)
   - Set Team (your Apple Developer account)
   - Set deployment target to macOS 13.0+

4. **Add App Icon**
   - Create an `.icns` file or use Asset Catalog
   - Add to Assets.xcassets

5. **Configure Info.plist**
   Add these keys:
   ```xml
   <key>LSUIElement</key>
   <true/>
   <key>LSMinimumSystemVersion</key>
   <string>13.0</string>
   ```

6. **Archive and Distribute**
   - Product → Archive
   - Click "Distribute App"
   - Choose "Direct Distribution" or "Developer ID"
   - Follow the wizard to export

---

## 🚀 **Option 2: Manual Build & Export (For Local Testing)**

If you just want to create a `.app` bundle for local use without the App Store:

### 1. Build the executable
```bash
cd /path/to/OverflowPeek
swift build -c release
```

### 2. Create app bundle structure
```bash
mkdir -p OverflowPeek.app/Contents/MacOS
mkdir -p OverflowPeek.app/Contents/Resources
```

### 3. Copy the executable
```bash
cp .build/release/OverflowPeek OverflowPeek.app/Contents/MacOS/
```

### 4. Create Info.plist
Create `OverflowPeek.app/Contents/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>OverflowPeek</string>
    <key>CFBundleIdentifier</key>
    <string>com.yourname.OverflowPeek</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Overflow Peek</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
```

### 5. Make it executable
```bash
chmod +x OverflowPeek.app/Contents/MacOS/OverflowPeek
```

### 6. Test it
```bash
open OverflowPeek.app
```

---

## 🎨 **Option 3: Use a Build Script**

Create a file called `build-app.sh`:

```bash
#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Building Overflow Peek...${NC}"

# Build release version
swift build -c release

if [ $? -ne 0 ]; then
    echo "Build failed!"
    exit 1
fi

echo -e "${GREEN}Build successful!${NC}"
echo -e "${BLUE}Creating app bundle...${NC}"

# Remove old app if exists
rm -rf OverflowPeek.app

# Create app structure
mkdir -p OverflowPeek.app/Contents/{MacOS,Resources}

# Copy executable
cp .build/release/OverflowPeek OverflowPeek.app/Contents/MacOS/

# Create Info.plist
cat > OverflowPeek.app/Contents/Info.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>OverflowPeek</string>
    <key>CFBundleIdentifier</key>
    <string>com.yourname.OverflowPeek</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Overflow Peek</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Make executable
chmod +x OverflowPeek.app/Contents/MacOS/OverflowPeek

echo -e "${GREEN}App bundle created successfully!${NC}"
echo -e "${BLUE}Location: $(pwd)/OverflowPeek.app${NC}"
echo ""
echo "To run: open OverflowPeek.app"
echo "To install: drag OverflowPeek.app to /Applications"
```

Make it executable and run:
```bash
chmod +x build-app.sh
./build-app.sh
```

---

## 📦 **Option 4: Create DMG for Distribution**

After creating the `.app` bundle:

```bash
# Create a DMG
hdiutil create -volname "Overflow Peek" -srcfolder OverflowPeek.app -ov -format UDZO OverflowPeek.dmg

# The DMG is now ready to share
```

---

## 🔐 **For Proper Distribution (Notarization)**

If you want to distribute outside the App Store:

1. **Get a Developer ID certificate**
   - Requires Apple Developer Program ($99/year)
   - Download from developer.apple.com

2. **Code sign the app**
   ```bash
   codesign --deep --force --verify --verbose --sign "Developer ID Application: Your Name" OverflowPeek.app
   ```

3. **Notarize with Apple**
   ```bash
   # Create a ZIP
   ditto -c -k --keepParent OverflowPeek.app OverflowPeek.zip
   
   # Submit for notarization
   xcrun notarytool submit OverflowPeek.zip --apple-id your@email.com --team-id TEAMID --wait
   
   # Staple the ticket
   xcrun stapler staple OverflowPeek.app
   ```

---

## 📝 **Recommended Path**

For a menu bar app like Overflow Peek:

1. ✅ **Start with Option 2** (Manual Build) for quick testing
2. ✅ **Use Option 3** (Build Script) for repeated builds  
3. ✅ **Eventually use Option 1** (Xcode Project) for final distribution
4. ✅ **Consider Option 4** (DMG) for easy sharing

---

## 🎯 **Quick Start (Get Running Now)**

Copy this into terminal in your project folder:

```bash
swift build -c release && \
rm -rf OverflowPeek.app && \
mkdir -p OverflowPeek.app/Contents/MacOS && \
cp .build/release/OverflowPeek OverflowPeek.app/Contents/MacOS/ && \
chmod +x OverflowPeek.app/Contents/MacOS/OverflowPeek && \
echo "Done! Run with: open OverflowPeek.app"
```

This creates a basic `.app` bundle you can double-click to run!

---

## ❓ **Why doesn't Archive work?**

Swift Package executables are designed for command-line tools, not GUI apps. When you click **Product → Archive**, Xcode doesn't know how to package it as a distributable macOS application because:

- No bundle identifier configured
- No Info.plist
- No code signing settings
- No app icon
- No entitlements file

Converting to a proper Xcode project solves all of these issues and gives you the standard "Distribute App" workflow.
