import AppKit

/// Fetches the list of running user-facing apps from NSWorkspace.
///
/// We include both `.regular` (Dock-style apps) and `.accessory` (menu-bar utilities)
/// activation policies, because surfacing menu-bar utilities is literally the point
/// of Overflow Peek. We filter out obvious background helpers, XPC services, and
/// non-user-facing system agents by name and bundle-id patterns.
@MainActor
final class AppListService {

    // Background helpers / agents masquerading as running apps.
    // Anything whose name OR bundle id matches one of these substrings is dropped.
    private static let backgroundPatterns: [String] = [
        " helper", "(helper)", ".helper",
        " agent", ".agent", " daemon", ".daemon",
        "xpcservice", "xpc service",
        "crashreporter", "diagnostic", "updater",
        "loginitem", "auto-update", "autoupdate",
        "webcontent", "renderer", "gpuprocess", "pluginprocess",
        "networkservice", "framework"
    ]

    // Apple background services that aren't user-facing apps.
    // (Avoids blanket-banning com.apple.*, which would hide Safari, Mail, Finder, etc.)
    private static let appleSystemDenylist: Set<String> = [
        "com.apple.controlcenter",
        "com.apple.dock",
        "com.apple.WindowManager",
        "com.apple.Spotlight",
        "com.apple.SystemUIServer",
        "com.apple.loginwindow",
        "com.apple.notificationcenterui",
        "com.apple.TextInputMenuAgent",
        "com.apple.TextInputSwitcher",
        "com.apple.UserNotificationCenter",
        "com.apple.coreservices.uiagent",
        "com.apple.WebKit.GPU",
        "com.apple.WebKit.Networking",
        "com.apple.WebKit.WebContent",
        "com.apple.ViewBridgeAuxiliary",
        "com.apple.PressAndHold",
        "com.apple.AirPlayUIAgent",
        "com.apple.controlstrip",
        "com.apple.TextInputSwitcher",
        "com.apple.universalaccess.lpA",
        "com.apple.dt.Xcode.SourceKit",
        "com.apple.CoreLocationAgent"
    ]

    func fetchAppList(
        pinnedBundleIDs: [String],
        excludedBundleIDs: [String],
        recentlyActiveBundleIDs: [String]
    ) -> [AppDetectionResult] {
        let apps = NSWorkspace.shared.runningApplications
        let activePID = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1

        // Dedupe by bundle identifier, preferring non-terminated and lower PID.
        var byBundle: [String: NSRunningApplication] = [:]
        for app in apps {
            guard !app.isTerminated else { continue }
            guard let bid = app.bundleIdentifier, !bid.isEmpty else { continue }
            if let existing = byBundle[bid] {
                if existing.processIdentifier > app.processIdentifier { byBundle[bid] = app }
            } else {
                byBundle[bid] = app
            }
        }

        let results = byBundle.values.compactMap { app -> AppDetectionResult? in
            guard let name = app.localizedName, !name.isEmpty else { return nil }
            guard let bundleID = app.bundleIdentifier else { return nil }

            // Drop our own process
            if bundleID == "com.overflowpeek.app" { return nil }

            // User-excluded apps are hidden
            if excludedBundleIDs.contains(bundleID) { return nil }

            let lcName = name.lowercased()
            let lcBID = bundleID.lowercased()

            // Drop curated Apple system services that aren't user-facing
            if Self.appleSystemDenylist.contains(bundleID) { return nil }

            // Anything spawned from /System/Library/ is a system service, preference pane,
            // settings extension, or framework helper — never a real user-facing app.
            // (Real Apple apps live in /System/Applications/ or /Applications/.)
            if let bundlePath = app.bundleURL?.path,
               bundlePath.hasPrefix("/System/Library/") {
                return nil
            }

            // System Settings panes that spawn as processes on macOS 13+ use bundle-id
            // patterns we can detect. Only apply these to Apple-owned bundle IDs so a
            // third-party app named "Settings something" isn't accidentally hidden.
            if bundleID.hasPrefix("com.apple.") {
                let appleExtensionPatterns = [
                    ".preference.", ".preferences.",
                    "settings",            // com.apple.wifi.WiFiSettings, com.apple.PrintScanSettings, etc.
                    ".extension", ".appex",
                    "preferencepane"
                ]
                if appleExtensionPatterns.contains(where: { lcBID.contains($0) }) {
                    return nil
                }
            }

            // Drop background helpers / agents by name + bundle-id substring match
            if Self.backgroundPatterns.contains(where: { lcName.contains($0) || lcBID.contains($0) }) {
                return nil
            }

            // Accept `.regular` and `.accessory`; drop `.prohibited`.
            let policy: String
            switch app.activationPolicy {
            case .regular:    policy = "regular"
            case .accessory:  policy = "accessory"
            case .prohibited: return nil
            @unknown default: return nil
            }

            // Apps with no executable URL are almost always processes we don't want.
            guard app.executableURL != nil else { return nil }

            let isActive = app.processIdentifier == activePID

            let confidence: AppConfidence
            if pinnedBundleIDs.contains(bundleID) {
                confidence = .pinned
            } else if isActive {
                confidence = .active
            } else if recentlyActiveBundleIDs.contains(bundleID) {
                confidence = .recentlyActive
            } else {
                confidence = .regular
            }

            let item = MenuBarAppItem(
                bundleIdentifier: bundleID,
                name: name,
                executablePath: app.executableURL?.path ?? "",
                pid: app.processIdentifier,
                activationPolicy: policy
            )

            return AppDetectionResult(item: item, confidence: confidence, isActive: isActive)
        }

        return results.sorted { lhs, rhs in
            let order: [AppConfidence] = [.pinned, .active, .recentlyActive, .regular]
            let li = order.firstIndex(of: lhs.confidence) ?? Int.max
            let ri = order.firstIndex(of: rhs.confidence) ?? Int.max
            if li != ri { return li < ri }
            // Within a section, sort alphabetically (locale-aware, case-insensitive).
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}
