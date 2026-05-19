import SwiftUI
import AppKit

/// Central state container for Overflow Peek.
/// Observes NSWorkspace notifications for live app list updates — no polling.
@MainActor
final class OverflowStore: ObservableObject {
    @Published var allApps: [AppDetectionResult] = []
    @Published var searchQuery: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    private let listService = AppListService()
    private let inclusionManager = InclusionExclusionManager()
    private let launchHistoryKey = "OverflowPeek.launchHistory"
    private let maxRecentHistory = 10

    var pinnedBundleIDs: [String] { inclusionManager.pinnedBundleIDs }
    var excludedBundleIDs: [String] { inclusionManager.excludedBundleIDs }

    @Published var recentlyActiveBundleIDs: [String] = []
    @Published var activeBundleID: String? = nil

    private var observers: [NSObjectProtocol] = []

    init() {
        loadRecentHistory()
        startObserving()
    }

    // MARK: - Workspace Observation

    private func startObserving() {
        let center = NSWorkspace.shared.notificationCenter

        observers.append(center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.rebuildAppList() })

        observers.append(center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.rebuildAppList() })

        observers.append(center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.rebuildAppList() })

        rebuildAppList()
    }

    private func stopObserving() {
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers.removeAll()
    }

    private func rebuildAppList() {
        let results = listService.fetchAppList(
            pinnedBundleIDs: pinnedBundleIDs,
            excludedBundleIDs: excludedBundleIDs,
            recentlyActiveBundleIDs: recentlyActiveBundleIDs
        )
        allApps = results

        if let active = NSWorkspace.shared.frontmostApplication {
            activeBundleID = active.bundleIdentifier
        } else {
            activeBundleID = nil
        }

        isLoading = false
        errorMessage = nil
    }

    // MARK: - Computed Properties

    var filteredApps: [AppDetectionResult] {
        guard !searchQuery.isEmpty else { return allApps }
        let query = searchQuery.lowercased()
        return allApps.filter { result in
            result.name.lowercased().contains(query) ||
            result.bundleIdentifier.lowercased().contains(query)
        }
    }

    var pinnedAppItems: [AppDetectionResult] {
        pinnedBundleIDs.compactMap { bundleID in
            allApps.first { $0.bundleIdentifier == bundleID }
        }
    }

    var recentlyActiveItems: [AppDetectionResult] {
        recentlyActiveBundleIDs.prefix(5).compactMap { bundleID in
            allApps.first { $0.bundleIdentifier == bundleID }
        }
    }

    var otherApps: [AppDetectionResult] {
        filteredApps.filter { result in
            !pinnedBundleIDs.contains(result.bundleIdentifier) &&
            !recentlyActiveBundleIDs.contains(result.bundleIdentifier)
        }
    }

    var activeApp: AppDetectionResult? {
        guard let bid = activeBundleID else { return nil }
        return allApps.first { $0.bundleIdentifier == bid }
    }

    // MARK: - App Management

    func activateApp(_ bundleID: String) {
        guard let app = NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == bundleID }) else {
            errorMessage = "App is not running"
            return
        }

        let success = app.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
        if success {
            recordLaunch(bundleID)
            errorMessage = nil
        } else {
            errorMessage = "Could not activate app"
        }
    }

    func recordLaunch(_ bundleID: String) {
        recentlyActiveBundleIDs.removeAll { $0 == bundleID }
        recentlyActiveBundleIDs.insert(bundleID, at: 0)
        if recentlyActiveBundleIDs.count > maxRecentHistory {
            recentlyActiveBundleIDs.removeLast()
        }
        saveRecentHistory()
    }

    func quitApp(_ bundleID: String) {
        guard let app = NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == bundleID }) else {
            errorMessage = "App is not running"
            return
        }
        let script = "tell application id \"\(bundleID)\" to quit"
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if error != nil {
                app.terminate()
            }
        } else {
            app.terminate()
        }
    }

    // MARK: - Pinning

    func pinApp(_ bundleID: String) {
        inclusionManager.pinApp(bundleID)
        rebuildAppList()
    }

    func unpinApp(_ bundleID: String) {
        inclusionManager.unpinApp(bundleID)
        rebuildAppList()
    }

    func isPinned(_ bundleID: String) -> Bool {
        inclusionManager.isPinned(bundleID)
    }

    // MARK: - Exclusions

    func excludeApp(_ bundleID: String) {
        inclusionManager.excludeApp(bundleID)
        rebuildAppList()
    }

    func removeExclusion(_ bundleID: String) {
        inclusionManager.removeExclusion(bundleID)
        rebuildAppList()
    }

    func isExcluded(_ bundleID: String) -> Bool {
        inclusionManager.isExcluded(bundleID)
    }

    // MARK: - Refresh (manual fallback — normally driven by notifications)

    func refreshRunningApps() {
        rebuildAppList()
    }

    // MARK: - Persistence

    private func saveRecentHistory() {
        if let data = try? JSONEncoder().encode(recentlyActiveBundleIDs) {
            UserDefaults.standard.set(data, forKey: launchHistoryKey)
        }
    }

    private func loadRecentHistory() {
        guard let data = UserDefaults.standard.data(forKey: launchHistoryKey),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return
        }
        recentlyActiveBundleIDs = decoded
    }
}
