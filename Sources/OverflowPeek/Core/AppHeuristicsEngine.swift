import AppKit
import CoreGraphics

// TECHNICAL NOTE: There is no public macOS API to enumerate third-party
// NSStatusItem/NSStatusBarButton instances or determine which menu bar icons
// are currently visible vs. hidden. Our heuristics use activation policy and
// naming patterns as probabilistic signals. This is advisory, not definitive.
// Users should pin apps they trust and hide apps they don't want to see.
//
// Signals ranked by reliability:
//   1. activationPolicy == .accessory (strongest public signal)
//   2. Bundle ID / app name heuristic patterns
//   3. No visible window detected via CGWindowList
//   4. User confirmation (pin = trust, exclude = hide)

/// Pure logic for scoring and detecting likely menu bar utility apps.
struct AppHeuristicsEngine {
    // Scoring thresholds
    static let detectionThreshold = 40

    // Known utility bundle ID patterns
    static let knownUtilityPatterns = [
        "menu", "bar", "statusbar", "popover", "tray", "system",
        "helper", "agent", "service", "tool", "manager", "monitor",
        "watcher", "daemon", "client", "dock", "window", "launcher",
        "shortcut", "clipboard", "snippet", "screenshot", "screen",
        "color", "picker", "note", "calendar", "todo", "reminder",
        "weather", "battery", "bluetooth", "wifi", "network", "vpn",
        "volume", "audio", "sound", "mic", "camera", "display",
        "keyboard", "mouse", "trackpad", "input", "output"
    ]

    // Common utility app prefixes
    static let utilityPathPrefixes = [
        "/Applications/Utilities/",
        "/opt/homebrew/",
        "/usr/local/opt/",
        "/Applications/Dev",
        "/Users/*/Library/Application Support"
    ]

    // System paths to exclude
    static let excludedPathPrefixes = [
        "/System/",
        "/usr/libexec/",
        "/Library/CoreMediaIO/",
    ]

    /// Score an app based on heuristic signals.
    static func scoreApp(_ app: NSRunningApplication) -> Int {
        var score = 0

        // Signal 1: Activation policy (.accessory is strong indicator)
        if app.activationPolicy == .accessory {
            score += 40
        }

        // Signal 2: Bundle ID patterns
        if let bundleID = app.bundleIdentifier {
            score += bundleIDScore(bundleID)
        }

        // Signal 3: Executable path
        if let path = app.executableURL?.path {
            score += executablePathScore(path)
        }

        // Signal 4: No main window (typical of menu bar apps)
        if !hasMainWindow(app) {
            score += 15
        }

        // Signal 5: App name patterns
        if let name = app.localizedName {
            score += appNameScore(name)
        }

        return score
    }

    /// Score bundle ID for utility indicators.
    static func bundleIDScore(_ bundleID: String) -> Int {
        var score = 0
        let lowercased = bundleID.lowercased()

        // Known utility patterns in bundle ID
        for pattern in knownUtilityPatterns {
            if lowercased.contains(pattern) {
                score += 15
                break  // Count pattern once
            }
        }

        // Apple apps are explicitly NOT utilities (in this context)
        if bundleID.hasPrefix("com.apple.") {
            score = -1000  // Flag for exclusion
        }

        // Three-part bundle IDs (com.vendor.app) are typically legit apps
        let parts = bundleID.split(separator: ".")
        if parts.count >= 3 {
            score += 10  // Proper bundle ID structure
        }

        return score
    }

    /// Score executable path for utility indicators.
    static func executablePathScore(_ path: String) -> Int {
        var score = 0

        // Exclude system paths
        for systemPath in excludedPathPrefixes {
            if path.hasPrefix(systemPath) {
                return -1000  // Flag for exclusion
            }
        }

        // Check for utility app paths
        for utilityPath in utilityPathPrefixes {
            if path.contains(utilityPath) {
                score += 20
                break
            }
        }

        // Home directory apps
        if path.contains(FileManager.default.homeDirectoryForCurrentUser.path) {
            score += 10
        }

        return score
    }

    /// Score app name for utility indicators.
    static func appNameScore(_ name: String) -> Int {
        var score = 0
        let lowercased = name.lowercased()

        // Utility naming patterns
        let utilityKeywords = ["helper", "agent", "monitor", "manager", "watcher", "service", "tool"]
        for keyword in utilityKeywords {
            if lowercased.contains(keyword) {
                score += 10
                break
            }
        }

        return score
    }

    /// Check if app has a visible main window.
    static func hasMainWindow(_ app: NSRunningApplication) -> Bool {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], CGWindowID(0)) as? [[String: Any]] else {
            return false
        }

        let appPID = app.processIdentifier
        for window in windows {
            if let windowPID = window[kCGWindowOwnerPID as String] as? Int32,
               windowPID == appPID {
                // Check if window is actually visible (not minimized, etc.)
                if let windowLevel = window[kCGWindowNumber as String] as? Int,
                   windowLevel > 0 {
                    return true
                }
            }
        }

        return false
    }

    /// Determine confidence level based on score and context.
    static func confidence(score: Int, bundleID: String, isPinned: Bool, isRecentlyActive: Bool) -> AppConfidence {
        if isPinned {
            return .pinned
        }
        if isRecentlyActive {
            return .recentlyActive
        }
        return .regular
    }
}
