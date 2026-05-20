import Foundation

/// Confidence level for an app in the list.
enum AppConfidence: String, Codable {
    case pinned = "Pinned"
    case recentlyActive = "Recently Active"
    case active = "Active"       // frontmost app right now
    case regular = "Running"     // standard running GUI app

    var badge: String {
        switch self {
        case .pinned: return "📌"
        case .recentlyActive: return "⏱"
        case .active: return "●"
        case .regular: return "◇"
        }
    }

    var description: String {
        switch self {
        case .pinned: return "Pinned"
        case .recentlyActive: return "Recently activated"
        case .active: return "Currently active"
        case .regular: return "Running"
        }
    }
}
