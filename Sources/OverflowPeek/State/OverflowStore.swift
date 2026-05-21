import SwiftUI
import AppKit

/// How the launcher window was opened. Drives content ordering, chrome, and footer.
enum InvocationMode {
    /// Menu-bar click → favorites/management-first ordering, full row actions.
    case manager
    /// Global keyboard shortcut → Spotlight-style switcher: Open Now first, minimal chrome.
    case switcher
}

/// Central state container for Overflow Peek.
/// Observes NSWorkspace notifications for live app list updates — no polling.
@MainActor
final class OverflowStore: ObservableObject {
    @Published var allApps: [AppDetectionResult] = []
    @Published var searchQuery: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var invocationMode: InvocationMode = .manager

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

        // Launch / terminate: full rebuild, because the candidate set changes.
        observers.append(center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.rebuildAppList() })

        observers.append(center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.rebuildAppList() })

        // Activation: cheap in-place update + recent-history tracking.
        observers.append(center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let self else { return }
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self.applyActivation(app)
        })

        rebuildAppList()
    }

    /// Cheap in-place active-flag update + recent-history bump.
    /// Avoids a full re-fetch from NSWorkspace for every focus change.
    private func applyActivation(_ app: NSRunningApplication?) {
        guard let app, let bid = app.bundleIdentifier else { return }

        // Auto-track activations from anywhere (Dock, Spotlight, Cmd-Tab, our launcher).
        // Skip our own process so opening the launcher doesn't pollute recent history.
        if bid != "com.overflowpeek.app" {
            recordLaunch(bid)
        }

        activeBundleID = bid

        // Patch isActive flags without rebuilding the whole list.
        var changed = false
        allApps = allApps.map { result in
            let nowActive = result.bundleIdentifier == bid
            if nowActive != result.isActive {
                changed = true
                return AppDetectionResult(item: result.item,
                                          confidence: result.confidence,
                                          isActive: nowActive)
            }
            return result
        }

        // If the activated app wasn't yet in the list (just launched + activated in
        // rapid succession, before launch notification flushed), fall back to rebuild.
        if !changed && !allApps.contains(where: { $0.bundleIdentifier == bid }) {
            rebuildAppList()
        }
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
        let q = searchQuery
        // Fuzzy match by name (preferred) or bundle id (fallback). Sorted by score desc.
        let scored = allApps.compactMap { result -> (AppDetectionResult, Int)? in
            let nameScore = Self.fuzzyScore(query: q, target: result.name) ?? -1
            let bidScore  = (Self.fuzzyScore(query: q, target: result.bundleIdentifier) ?? -1) / 2
            let best = max(nameScore, bidScore)
            return best > 0 ? (result, best) : nil
        }
        return scored.sorted { $0.1 > $1.1 }.map { $0.0 }
    }

    /// Apps to surface in switcher mode's top "Open Now" section: every filtered app
    /// except the frontmost (so the list always biases toward switching to *another*
    /// app) and except favorites that are already listed in their own section.
    func openNowItems(excludingFavoriteBundleIDs favoriteBundleIDs: Set<String>) -> [AppDetectionResult] {
        let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        return filteredApps.filter { result in
            if result.bundleIdentifier == frontmost { return false }
            if favoriteBundleIDs.contains(result.bundleIdentifier) { return false }
            return true
        }
    }

    /// Lightweight subsequence fuzzy match. Returns nil if not all query characters
    /// can be found in order; otherwise returns a heuristic score (higher = better).
    /// Bonuses: consecutive matches, word-start matches, prefix match.
    static func fuzzyScore(query: String, target: String) -> Int? {
        let q = Array(query.lowercased())
        let t = Array(target.lowercased())
        guard !q.isEmpty else { return 0 }
        var qi = 0
        var score = 0
        var consecutive = 0
        var prevWasSeparator = true
        for (ti, ch) in t.enumerated() {
            if qi < q.count && ch == q[qi] {
                var bonus = 1
                if ti == qi { bonus += 4 }              // prefix match
                if prevWasSeparator { bonus += 3 }      // matches at word start
                consecutive += 1
                bonus += consecutive
                score += bonus
                qi += 1
            } else {
                consecutive = 0
            }
            prevWasSeparator = (ch == " " || ch == "-" || ch == "_" || ch == ".")
        }
        return qi == q.count ? score : nil
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
            .first(where: { $0.bundleIdentifier == bundleID && !$0.isTerminated }) else {
            errorMessage = "App is not running"
            return
        }

        // If the app is hidden, unhiding alone is sometimes enough; otherwise activate.
        if app.isHidden { app.unhide() }

        let success: Bool
        if #available(macOS 14.0, *) {
            // Modern API: doesn't take options, brings the app forward.
            app.activate()
            success = true
        } else {
            success = app.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
        }

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
        let candidates = NSWorkspace.shared.runningApplications.filter {
            !$0.isTerminated && $0.bundleIdentifier == bundleID
        }
        guard !candidates.isEmpty else {
            errorMessage = "App is not running"
            return
        }
        errorMessage = nil

        for app in candidates {
            _ = app.terminate()
            // Some apps (Electron-based menu bar apps in particular) intercept the
            // standard quit AppleEvent and stay alive. If the process is still around
            // after a grace period, force-quit it.
            let pid = app.processIdentifier
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if let still = NSRunningApplication(processIdentifier: pid), !still.isTerminated {
                    _ = still.forceTerminate()
                }
            }
        }

        // Refresh after the grace period so the row updates from "Running" → gone.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.rebuildAppList()
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
