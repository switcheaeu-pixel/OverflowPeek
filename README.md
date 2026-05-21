# Overflow Peek

Find and activate your menu bar utility apps when the macOS menu bar gets crowded.

**Built for power users. Honest about what it detects.**

## What It Does

Overflow Peek uses heuristics to discover likely menu bar utility apps from your running applications — then presents them in a compact, keyboard-friendly popover so you can activate them with a single click.

- Detects likely menu bar utility apps (activation policy, naming patterns)
- Pin your favorites so they always appear at the top
- Search across all detected apps in real-time
- Full keyboard navigation support (↑↓ arrows, Return to activate, Esc to close)
- Launch at login ready via SMAppService

## What It Does NOT Do

- Does **not** claim to detect whether third-party icons are currently hidden behind system items (no public API exists for this)
- Does **not** host or re-parent other apps' menu bar icons
- Does **not** show "all menu bar applications" — only likely candidates
- Does **not** use private APIs

## Technical Limitations (Honest Disclosure)

macOS does not expose a public API to enumerate third-party `NSStatusItem` instances or determine which menu bar icons are currently visible vs. hidden. Overflow Peek uses probabilistic heuristics:

1. `activationPolicy == .accessory` (strongest signal)
2. Bundle ID / app naming patterns
3. User confirmation via pinning and exclusion

Detection is advisory. You control what appears by pinning apps you trust and hiding apps you don't.

## Requirements

- macOS 13.0+ (Ventura or later)
- Apple Silicon or Intel Mac

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `Cmd+Shift+M` | Toggle popover |
| `↑↓` | Navigate app list |
| `Return` | Activate selected app |
| `Esc` | Close popover |
| `Cmd+F` | Focus search field |
| `Cmd+R` | Refresh apps |
| `Cmd+,` | Open Settings |

## Build

```bash
xcodegen generate
xcodebuild -project OverflowPeek.xcodeproj -scheme OverflowPeek -configuration Release build
open OverflowPeek.app
```

## Architecture

- **SwiftUI + AppKit** for the popover interface
- **NSStatusItem + NSPopover** for the menu bar integration
- **LSUIElement = true** — no dock icon, background utility
- **SMAppService.mainApp** for launch-at-login
- **NSWorkspace.runningApplications** for app discovery
- **Heuristic scoring engine** for detecting likely menu bar utilities
