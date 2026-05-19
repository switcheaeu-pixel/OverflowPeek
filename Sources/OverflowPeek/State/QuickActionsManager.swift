import Foundation
import AppKit

/// Persisted list of "quick action" apps shown as clickable icons in the popover footer.
/// The user can add, remove, and reorder them from Settings → General → Quick Actions.
@MainActor
final class QuickActionsManager: ObservableObject {
    static let shared = QuickActionsManager()

    @Published private(set) var paths: [String]

    private let defaultsKey = "OverflowPeek.quickActionPaths"

    private static let defaultPaths: [String] = [
        "/Applications/LocalSend.app",
        "/System/Applications/Utilities/Activity Monitor.app"
    ]

    private init() {
        if let saved = UserDefaults.standard.array(forKey: defaultsKey) as? [String] {
            self.paths = saved
        } else {
            self.paths = Self.defaultPaths
        }
    }

    func add(_ path: String) {
        guard !paths.contains(path) else { return }
        paths.append(path)
        persist()
    }

    func remove(at index: Int) {
        guard paths.indices.contains(index) else { return }
        paths.remove(at: index)
        persist()
    }

    func move(from source: IndexSet, to destination: Int) {
        paths.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    func resetToDefaults() {
        paths = Self.defaultPaths
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(paths, forKey: defaultsKey)
    }

    /// Display name for an app at the given path (falls back to last path component).
    static func displayName(for path: String) -> String {
        let url = URL(fileURLWithPath: path)
        if let bundle = Bundle(url: url),
           let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                  ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String {
            return name
        }
        return url.deletingPathExtension().lastPathComponent
    }
}
