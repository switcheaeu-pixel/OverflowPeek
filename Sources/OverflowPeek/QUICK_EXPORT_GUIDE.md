App# 🚀 Quick Export Guide for Overflow Peek

## The Problem
**Product → Archive** doesn't show distribution options because this is a Swift Package, not a traditional Xcode project.

---

## ✅ **Quick Solution (Use This Now)**

### **1. Make the build script executable:**
```bash
chmod +x build-app.sh
```

### **2. Run the build script:**
```bash
./build-app.sh
```

### **3. You now have `OverflowPeek.app` ready to use!**

---

## 📦 **What You Get**

After running the script:
- ✅ **OverflowPeek.app** - A double-clickable macOS application
- ✅ **Properly configured** with Info.plist
- ✅ **Menu bar app** (LSUIElement = true)
- ✅ **Ready to copy** to /Applications

---

## 🎯 **How to Use Your App**

### **Option A: Run from current directory**
```bash
open OverflowPeek.app
```

### **Option B: Install to Applications folder**
```bash
cp -r OverflowPeek.app /Applications/
```

Then open from Spotlight or Applications folder!

### **Option C: Create a DMG for sharing**
```bash
hdiutil create -volname "Overflow Peek" -srcfolder OverflowPeek.app -ov -format UDZO OverflowPeek.dmg
```

Share the `.dmg` file with others!

---

## 🔄 **Update Workflow**

Every time you make code changes:

1. **Edit your Swift files**
2. **Run the build script:**
   ```bash
   ./build-app.sh
   ```
3. **Test the app:**
   ```bash
   open OverflowPeek.app
   ```

That's it! The script rebuilds everything automatically.

---

## 🎨 **Add an App Icon (Optional)**

To add a custom icon:

1. **Create or download an icon** (512x512 PNG or higher)

2. **Convert to ICNS:**
   ```bash
   # Create iconset folder
   mkdir MyIcon.iconset
   
   # Add different sizes (use your icon.png)
   sips -z 16 16     icon.png --out MyIcon.iconset/icon_16x16.png
   sips -z 32 32     icon.png --out MyIcon.iconset/icon_16x16@2x.png
   sips -z 32 32     icon.png --out MyIcon.iconset/icon_32x32.png
   sips -z 64 64     icon.png --out MyIcon.iconset/icon_32x32@2x.png
   sips -z 128 128   icon.png --out MyIcon.iconset/icon_128x128.png
   sips -z 256 256   icon.png --out MyIcon.iconset/icon_128x128@2x.png
   sips -z 256 256   icon.png --out MyIcon.iconset/icon_256x256.png
   sips -z 512 512   icon.png --out MyIcon.iconset/icon_256x256@2x.png
   sips -z 512 512   icon.png --out MyIcon.iconset/icon_512x512.png
   sips -z 1024 1024 icon.png --out MyIcon.iconset/icon_512x512@2x.png
   
   # Convert to ICNS
   iconutil -c icns MyIcon.iconset
   
   # Move to app bundle
   cp MyIcon.icns OverflowPeek.app/Contents/Resources/AppIcon.icns
   ```

3. **Update Info.plist** (add this key):
   ```bash
   # Add to the <dict> section in OverflowPeek.app/Contents/Info.plist
   <key>CFBundleIconFile</key>
   <string>AppIcon</string>
   ```

---

## 🔐 **For Distribution (Advanced)**

If you want to share with others outside the Mac App Store:

### **Requirements:**
- Apple Developer Program membership ($99/year)
- Developer ID certificate

### **Steps:**

1. **Code sign the app:**
   ```bash
   codesign --deep --force --sign "Developer ID Application: Your Name" OverflowPeek.app
   ```

2. **Create ZIP for notarization:**
   ```bash
   ditto -c -k --keepParent OverflowPeek.app OverflowPeek.zip
   ```

3. **Submit for notarization:**
   ```bash
   xcrun notarytool submit OverflowPeek.zip \
       --apple-id your@email.com \
       --team-id YOURTEAMID \
       --password "app-specific-password" \
       --wait
   ```

4. **Staple the ticket:**
   ```bash
   xcrun stapler staple OverflowPeek.app
   ```

5. **Create DMG:**
   ```bash
   hdiutil create -volname "Overflow Peek" \
       -srcfolder OverflowPeek.app \
       -ov -format UDZO \
       OverflowPeek.dmg
   ```

---

## ❓ **Why Doesn't Archive Work?**

Swift Package Manager (SPM) projects are designed for:
- ✅ Command-line tools
- ✅ Libraries
- ✅ Server-side apps

**NOT** for:
- ❌ GUI macOS apps with icons
- ❌ App Store distribution
- ❌ Code signing workflows

That's why **Product → Archive** doesn't show the "Distribute App" options.

---

## 🔮 **Long-Term Solution**

For a production app, you should:

1. **Convert to an Xcode project** (see `EXPORT_FOR_DISTRIBUTION.md`)
2. **Get a Developer ID certificate**
3. **Set up proper code signing**
4. **Configure notarization**

This gives you:
- ✅ Automatic updates
- ✅ Proper icon support
- ✅ Easy archiving
- ✅ App Store submission (if desired)

---

## 🆘 **Troubleshooting**

### **"Permission denied" error**
```bash
chmod +x build-app.sh
```

### **"No such file or directory"**
Make sure you're in the project root:
```bash
cd /path/to/OverflowPeek
ls  # Should see Package.swift
```

### **App won't open**
Check if it's built:
```bash
ls OverflowPeek.app/Contents/MacOS/
```

Should show `OverflowPeek` file.

### **"App is damaged" error**
macOS Gatekeeper is blocking it. Right-click → Open, or:
```bash
xattr -cr OverflowPeek.app
```

---

## 📋 **Summary**

| Goal | Command |
|------|---------|
| Build app | `./build-app.sh` |
| Run app | `open OverflowPeek.app` |
| Install app | `cp -r OverflowPeek.app /Applications/` |
| Create DMG | `hdiutil create -volname "Overflow Peek" -srcfolder OverflowPeek.app -ov -format UDZO OverflowPeek.dmg` |
| Share with others | Share the `.dmg` file |

---

**🎉 That's it! You now have a distributable macOS app!**

For more details, see `EXPORT_FOR_DISTRIBUTION.md`
