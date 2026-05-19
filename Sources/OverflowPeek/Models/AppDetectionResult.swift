import Foundation

/// A running application presented in the app list.
struct AppDetectionResult: Identifiable, Equatable {
    let id: String
    let item: MenuBarAppItem
    let confidence: AppConfidence
    let isActive: Bool

    var bundleIdentifier: String { item.bundleIdentifier }
    var name: String { item.name }
    var executablePath: String { item.executablePath }

    init(item: MenuBarAppItem, confidence: AppConfidence, isActive: Bool = false) {
        self.id = item.bundleIdentifier
        self.item = item
        self.confidence = confidence
        self.isActive = isActive
    }

    static func == (lhs: AppDetectionResult, rhs: AppDetectionResult) -> Bool {
        lhs.id == rhs.id
    }
}
