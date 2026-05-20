import SwiftUI
import AppKit

/// Manages the favorite apps list with persistence, launch, and terminate support.
@MainActor
final class FavoriteAppsViewModel: ObservableObject {
    @Published var favorites: [FavoriteApp] = []
    @Published var runningBundleIDs: Set<String> = []

    private let storageKey = "OverflowPeek.favoriteApps"
    private var observers: [NSObjectProtocol] = []

    init() {
        load()
        startObserving()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([FavoriteApp].self, from: data) else {
            return
        }
        favorites = decoded
        refreshRunningState()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    // MARK: - Add / Remove

    func addApp(from url: URL) {
        let bundle = Bundle(url: url)
        let name = bundle?.infoDictionary?["CFBundleName"] as? String
            ?? bundle?.infoDictionary?["CFBundleDisplayName"] as? String
            ?? url.deletingPathExtension().lastPathComponent
        let bid = bundle?.bundleIdentifier

        let bookmark = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        let fav = FavoriteApp(
            name: name,
            path: url.path,
            bundleIdentifier: bid,
            bookmarkData: bookmark
        )

        guard !favorites.contains(where: { $0.id == fav.id }) else { return }
        favorites.append(fav)
        save()
        refreshRunningState()
    }

    func removeApp(_ fav: FavoriteApp) {
        favorites.removeAll { $0.id == fav.id }
        save()
        refreshRunningState()
    }

    func moveFavorite(from source: IndexSet, to destination: Int) {
        favorites.move(fromOffsets: source, toOffset: destination)
        save()
    }

    // MARK: - Actions

    func launchApp(_ fav: FavoriteApp) {
        let config = NSWorkspace.OpenConfiguration()
        if let bid = fav.bundleIdentifier,
           let runningApp = NSWorkspace.shared.runningApplications.first(where: {
               $0.bundleIdentifier == bid && !$0.isTerminated
           }) {
            runningApp.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
        } else {
            NSWorkspace.shared.openApplication(at: fav.url, configuration: config) { _, error in
                if let error = error {
                    print("[FavoriteApps] launch failed: \(error.localizedDescription)")
                }
            }
        }
        refreshRunningState()
    }

    func terminateApp(_ fav: FavoriteApp) {
        let candidates = NSWorkspace.shared.runningApplications.filter { app in
            guard !app.isTerminated else { return false }
            if let bid = fav.bundleIdentifier, app.bundleIdentifier == bid { return true }
            if let bundleURL = app.bundleURL?.standardizedFileURL.path,
               bundleURL == URL(fileURLWithPath: fav.path).standardizedFileURL.path {
                return true
            }
            return false
        }
        guard !candidates.isEmpty else { return }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.refreshRunningState()
        }
    }

    // MARK: - State

    func isRunning(_ fav: FavoriteApp) -> Bool {
        if let bid = fav.bundleIdentifier {
            return runningBundleIDs.contains(bid)
        }
        return false
    }

    func refreshRunningState() {
        let running = NSWorkspace.shared.runningApplications
            .compactMap { $0.bundleIdentifier }
        runningBundleIDs = Set(running)
    }

    // MARK: - Observation

    private func startObserving() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification,
                     NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.didActivateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.refreshRunningState()
            })
        }
    }

    }
