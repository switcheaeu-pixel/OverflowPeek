import ServiceManagement
import Foundation

/// Thin wrapper around SMAppService for launch-at-login support (macOS 13+)
@MainActor
final class LaunchAtLoginManager: ObservableObject {
    @Published var isEnabled: Bool = false

    private let service = SMAppService.mainApp

    init() {
        refresh()
    }

    func refresh() {
        isEnabled = service.status == .enabled
    }

    func toggle() {
        do {
            if isEnabled {
                try service.unregister()
            } else {
                try service.register()
            }
            refresh()
        } catch {
            print("LaunchAtLogin toggle failed: \(error)")
        }
    }
}
