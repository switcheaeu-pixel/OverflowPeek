import AppKit

/// Fetches the list of running regular GUI apps from NSWorkspace.
/// No heuristics, no scoring — just runningApplications filtered to .regular policy.
@MainActor
final class AppListService {

    func fetchAppList(
        pinnedBundleIDs: [String],
        excludedBundleIDs: [String],
        recentlyActiveBundleIDs: [String]
    ) -> [AppDetectionResult] {
        let apps = NSWorkspace.shared.runningApplications
        let activeApp = NSWorkspace.shared.frontmostApplication
        let activePID = activeApp?.processIdentifier ?? -1

        let results = apps.compactMap { app -> AppDetectionResult? in
            guard let name = app.localizedName, !name.isEmpty else { return nil }
            guard let bundleID = app.bundleIdentifier, !bundleID.isEmpty else { return nil }

            // Only regular GUI apps — no background or accessory processes
            guard app.activationPolicy == .regular else { return nil }

            // Exclude Apple system apps and ourselves
            if bundleID.hasPrefix("com.apple.") || bundleID == "com.overflowpeek.app" {
                return nil
            }

            // User-excluded apps are hidden from the list
            if excludedBundleIDs.contains(bundleID) {
                return nil
            }

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
                activationPolicy: "regular"
            )

            return AppDetectionResult(item: item, confidence: confidence, isActive: isActive)
        }

        return results.sorted { lhs, rhs in
            let order: [AppConfidence] = [.pinned, .active, .recentlyActive, .regular]
            let li = order.firstIndex(of: lhs.confidence) ?? Int.max
            let ri = order.firstIndex(of: rhs.confidence) ?? Int.max
            if li != ri { return li < ri }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}
