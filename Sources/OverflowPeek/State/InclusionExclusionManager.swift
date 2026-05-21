import Foundation

/// Manages user's pinned and excluded app lists with persistence.
@MainActor
final class InclusionExclusionManager {
    private let pinnedKey = "OverflowPeek.pinnedApps"
    private let excludedKey = "OverflowPeek.excludedApps"

    var pinnedBundleIDs: [String] = []
    var excludedBundleIDs: [String] = []

    init() {
        loadPinned()
        loadExcluded()
    }

    // MARK: - Pinned Apps

    func pinApp(_ bundleID: String) {
        guard !pinnedBundleIDs.contains(bundleID) else { return }
        pinnedBundleIDs.append(bundleID)
        savePinned()
    }

    func unpinApp(_ bundleID: String) {
        pinnedBundleIDs.removeAll { $0 == bundleID }
        savePinned()
    }

    func isPinned(_ bundleID: String) -> Bool {
        pinnedBundleIDs.contains(bundleID)
    }

    // MARK: - Excluded Apps

    func excludeApp(_ bundleID: String) {
        guard !excludedBundleIDs.contains(bundleID) else { return }
        excludedBundleIDs.append(bundleID)
        saveExcluded()
    }

    func removeExclusion(_ bundleID: String) {
        excludedBundleIDs.removeAll { $0 == bundleID }
        saveExcluded()
    }

    func isExcluded(_ bundleID: String) -> Bool {
        excludedBundleIDs.contains(bundleID)
    }

    // MARK: - Persistence

    private func savePinned() {
        if let data = try? JSONEncoder().encode(pinnedBundleIDs) {
            UserDefaults.standard.set(data, forKey: pinnedKey)
        }
    }

    private func loadPinned() {
        guard let data = UserDefaults.standard.data(forKey: pinnedKey),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return
        }
        pinnedBundleIDs = decoded
    }

    private func saveExcluded() {
        if let data = try? JSONEncoder().encode(excludedBundleIDs) {
            UserDefaults.standard.set(data, forKey: excludedKey)
        }
    }

    private func loadExcluded() {
        guard let data = UserDefaults.standard.data(forKey: excludedKey),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return
        }
        excludedBundleIDs = decoded
    }
}
