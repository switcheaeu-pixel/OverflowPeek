import AppKit
import Foundation

extension URL {
    var appBundleURL: URL {
        let path = self.path
        let components = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        let bundleIndex = components.lastIndex { $0.hasSuffix(".app") } ?? components.count
        return URL(fileURLWithPath: "/" + components[0..<(bundleIndex + 1)].joined(separator: "/"))
    }
}

extension NSRunningApplication {
    var appBundleURL: URL? {
        executableURL?.appBundleURL
    }
}

extension FileManager {
    func getIcon(for path: String) -> NSImage? {
        let icon = NSWorkspace.shared.icon(forFile: path)
        return icon.representations.isEmpty ? nil : icon
    }

    func getApplicationBundleURL(from executablePath: String) -> URL? {
        let url = URL(fileURLWithPath: executablePath)
        let bundleURL = url.appBundleURL
        return bundleURL.pathExtension == "app" ? bundleURL : nil
    }
}

enum AppAction {
    case pin(bundleID: String, name: String, executablePath: String?)
    case unpin(bundleID: String)
    case activate(bundleID: String)
    case launch(bundleID: String, path: String?)
    case quit(bundleID: String)
    case revealInFinder(path: String)
}
