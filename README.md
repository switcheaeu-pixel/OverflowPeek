# Overflow Peek

A lightweight macOS menu-bar app that gives you a fast, keyboard-driven launcher for your favorite apps and a clean view of everything currently running.

Press a global shortcut anywhere on your Mac — a small floating window appears at the center of the screen with your favorites, your most-recently-active apps, and the full list of running applications. Pick one with the arrow keys, hit Return, and it's frontmost. Click anywhere else and the window disappears.

---

## What it does

- **Global keyboard launcher.** One shortcut from anywhere opens a centered, focused window. Press it again — or click outside — to dismiss.
- **Favorites with one-click control.** Pin the apps you use constantly. Each row shows live running state and lets you launch, activate, or quit (red X) in a single click.
- **Running-apps inventory.** Pinned, recently active, and all other running apps are grouped into clear sections. Search across them with a single text field.
- **Quick-action footer.** Custom row of app icons in the launcher's footer for things like Activity Monitor or LocalSend. Fully user-configurable.
- **Stays out of your way.** Lives in the menu bar only — no Dock icon, no background services.

---

## Install

### Option 1 — Prebuilt app

1. Download `OverflowPeek.app` from this repository.
2. Drag it into `/Applications`.
3. Double-click to launch. macOS may show a "downloaded from the internet" warning the first time — right-click the app and choose **Open** to bypass it.

The menu bar icon (a small grid of rounded tiles) appears at the top of the screen.

### Option 2 — Build from source

Requirements:

- macOS 13 or later
- Xcode 15 or later (with command-line tools installed)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`

```bash
git clone <your-fork-url>
cd <repo>
./build.sh
open ./OverflowPeek.app
```

`build.sh` regenerates the Xcode project from `project.yml`, builds the Release configuration, strips quarantine attributes, and ad-hoc-signs the binary.

---

## Using it

### Default shortcuts

| Action | Shortcut |
| --- | --- |
| Open / close the launcher | **⌘⇧M** *(customizable)* |
| Navigate the list | ↑ ↓ |
| Activate the highlighted app | Return |
| Close the launcher | Esc, or click outside it |
| Open Settings | Right-click the menu bar icon → Settings |
| Quit Overflow Peek | Right-click the menu bar icon → Quit |

> Avoid single ⌘+digit combinations for the global shortcut. macOS reserves them for the frontmost app (tab switching, workspace navigation, etc.), and they will be intercepted before reaching Overflow Peek. Pair ⌘ with **Shift / Option / Ctrl** for reliable results.

### Settings

Open Settings from the menu bar icon (right-click → Settings, or ⌘,).

- **General → Behaviour**
  - **Launch at Login** — start the app automatically at boot.
- **General → Auto-Refresh**
  - Background re-scan of running apps every 10 seconds.
- **General → Running Apps**
  - Live count and a manual **Refresh Now** button.
- **General → Quick Actions**
  - Edit the list of icons shown in the launcher's footer. Add any `.app`, remove individually, or reset to defaults (LocalSend + Activity Monitor).
- **General → Keyboard Shortcuts**
  - Record a custom global hotkey.
- **Favorite Apps**
  - Manage the pinned-favorites list. Add apps via the picker; reorder by drag in the launcher.

### Permissions

The global shortcut works without any system permissions — Overflow Peek uses Carbon hotkeys, which don't require Accessibility access. A one-time optional prompt offers to enable Accessibility as a fallback path; you can always dismiss it permanently.

---

## How it works

Overflow Peek is a small SwiftUI / AppKit hybrid:

- A status item in the menu bar driven by `StatusItemController`.
- A global hotkey registered through Carbon (`HotKeyManager`), with an `NSEvent`-based backup monitor for cases where another app shadows it.
- The launcher is a borderless `NSWindow` hosting a SwiftUI view, recentered every time it opens.
- Running apps are sampled from `NSWorkspace.runningApplications` and filtered using a small heuristics engine (`AppHeuristicsEngine`) that scores each candidate as a likely menu-bar utility.
- Favorites, pinned apps, excluded apps, the global shortcut, and the quick-action list are all persisted via `UserDefaults`.

### Project layout

```
.
├── OverflowPeek.app          Prebuilt, ready to run
├── Sources/OverflowPeek/     Swift source
│   ├── AppDelegate.swift     App lifecycle, hotkey wiring, status menu
│   ├── OverflowPeekApp.swift SwiftUI App entry point
│   ├── Core/                 Status item, hotkey, popover, discovery, heuristics
│   ├── Models/               FavoriteApp, MenuBarAppItem, detection types
│   ├── State/                OverflowStore, QuickActionsManager, exclusion list
│   ├── UI/                   PopoverView and components
│   └── Resources/            AppIcon.icns, localizable strings
├── Info.plist                Bundle metadata (regenerated by xcodegen)
├── project.yml               XcodeGen spec — source of truth for project settings
├── Package.swift             Alternative SPM build path
├── OverflowPeek.xcconfig     Build settings overlay
├── AppIcon.icns              Compiled icon
├── AppIcon.iconset/          Per-size PNGs used to build the .icns
├── generate_icon.swift       Procedural icon generator
└── build.sh                  One-shot build script
```

### Regenerating the icon

The dock/Finder icon is generated from code. To redesign or rebuild it:

```bash
swift generate_icon.swift
iconutil -c icns AppIcon.iconset -o AppIcon.icns
cp AppIcon.icns Sources/OverflowPeek/Resources/AppIcon.icns
./build.sh
```

The menu bar icon is drawn programmatically in `StatusItemController.makeMenuBarIcon()` (template style, adapts to light/dark menu bars automatically).

---

## Uninstall

```bash
rm -rf /Applications/OverflowPeek.app
defaults delete com.overflowpeek.app
```

The `defaults delete` line removes all persisted state: favorites, pinned apps, exclusion list, quick actions, and the recorded keyboard shortcut.

---

## Contributing

Pull requests welcome. A few ground rules:

- Keep the menu bar icon small and template-style (single color, no gradients) so it adapts to system theming.
- The launcher should remain keyboard-first. Mouse affordances are fine, but every action must be reachable from the keyboard.
- Avoid features that require additional permissions. Anything that needs Accessibility or Automation should be opt-in and clearly documented.

---

## License

MIT. Use, modify, redistribute. No warranty.
