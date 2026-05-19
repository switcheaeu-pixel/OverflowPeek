import Foundation

/// A user-selected favorite application for quick launching.
struct FavoriteApp: Identifiable, Codable, Equatable {
    var id: String { bundleIdentifier ?? path }
    let name: String
    let path: String
    let bundleIdentifier: String?
    var bookmarkData: Data?

    var url: URL { URL(fileURLWithPath: path) }

    init(name: String, path: String, bundleIdentifier: String?, bookmarkData: Data? = nil) {
        self.name = name
        self.path = path
        self.bundleIdentifier = bundleIdentifier
        self.bookmarkData = bookmarkData
    }
}
