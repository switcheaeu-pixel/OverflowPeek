import AppKit
import SwiftUI

/// Manages the NSPopover (menu bar mode) and a dedicated NSWindow (shortcut mode).
@MainActor
final class PopoverController: NSObject, NSPopoverDelegate {
    private let popover = NSPopover()
    private var shortcutWindow: NSWindow?
    private var shortcutWindowTargetHeight: CGFloat = 160
    private var clickOutsideMonitor: Any?
    private let store: OverflowStore
    private let favVM: FavoriteAppsViewModel
    private let onOpenSettings: () -> Void
    private let onAppLaunched: () -> Void

    private static let width: CGFloat = 320
    private static let minHeight: CGFloat = 160
    private static let maxHeight: CGFloat = 520

    @Published var isShown = false

    init(store: OverflowStore, favVM: FavoriteAppsViewModel, onOpenSettings: @escaping () -> Void, onAppLaunched: @escaping () -> Void) {
        self.store = store
        self.favVM = favVM
        self.onOpenSettings = onOpenSettings
        self.onAppLaunched = onAppLaunched
        super.init()
        setupPopover()
    }

    private func setupPopover() {
        popover.behavior = .transient
        popover.animates = false
        popover.contentSize = NSSize(width: Self.width, height: Self.minHeight)
        popover.delegate = self
    }

    func show(relativeTo rect: NSRect, of view: NSView) {
        setupContent(for: popover)
        popover.show(relativeTo: rect, of: view, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        isShown = true
    }

    func showAtScreenCenter() {
        guard NSScreen.main != nil else { return }

        if shortcutWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: Self.width, height: Self.minHeight),
                styleMask: [.titled, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.isReleasedWhenClosed = false
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.hasShadow = true
            window.backgroundColor = .clear
            window.isOpaque = false
            shortcutWindow = window
        }

        setupContent(for: nil, window: shortcutWindow)
        NSApp.activate(ignoringOtherApps: true)
        shortcutWindow?.makeKeyAndOrderFront(nil)

        // Close when the user clicks anywhere outside our app (another app's window or the desktop).
        // Global monitors only fire for events delivered to OTHER apps, so clicks inside the
        // floating window itself never trigger this.
        if clickOutsideMonitor == nil {
            clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] _ in
                Task { @MainActor in self?.close() }
            }
        }

        recenterShortcutWindow()

        isShown = true
    }

    func close() {
        popover.performClose(nil)
        shortcutWindow?.orderOut(nil)
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
        isShown = false
    }

    func toggle(relativeTo rect: NSRect, of view: NSView) {
        if isShown {
            close()
        } else {
            show(relativeTo: rect, of: view)
        }
    }

    // MARK: - Content

    private func makeContentView() -> some View {
        PopoverView(onOpenSettings: onOpenSettings, onAppLaunched: onAppLaunched)
            .environmentObject(store)
            .environmentObject(favVM)
            .background(
                VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            )
    }

    private func setupContent(for popover: NSPopover) {
        store.refreshRunningApps()
        let hosting = ResponsiveHostingController(rootView: makeContentView())
        hosting.onSizeChanged = { [weak self] size in
            self?.updatePopoverSize(contentHeight: size.height)
        }
        popover.contentViewController = hosting
    }

    private func setupContent(for popover: NSPopover?, window: NSWindow?) {
        store.refreshRunningApps()
        let hosting = ResponsiveHostingController(rootView: makeContentView())
        hosting.onSizeChanged = { [weak self] size in
            guard let self, let w = window else { return }
            let footer: CGFloat = 32
            let target = min(max(size.height + footer, Self.minHeight), Self.maxHeight)
            self.shortcutWindowTargetHeight = target
            w.setContentSize(NSSize(width: Self.width, height: target))
            self.recenterShortcutWindow()
        }
        if let w = window {
            w.contentViewController = hosting
            if w.frame.width == 0 || w.frame.height == 0 {
                w.setContentSize(NSSize(width: Self.width, height: Self.minHeight))
            }
        }
    }

    private func updatePopoverSize(contentHeight: CGFloat) {
        let footer: CGFloat = 32
        let targetHeight = contentHeight + footer
        let clamped = min(max(targetHeight, Self.minHeight), Self.maxHeight)
        popover.contentSize = NSSize(width: Self.width, height: clamped)
    }

    // MARK: - NSPopoverDelegate

    func popoverDidClose(_ notification: Notification) {
        isShown = false
        store.searchQuery = ""
    }

    func recenterShortcutWindow() {
        guard let window = shortcutWindow, let screen = NSScreen.main else { return }
        DispatchQueue.main.async {
            guard let window = self.shortcutWindow, let screen = NSScreen.main else { return }
            let screenFrame = screen.visibleFrame
            let winFrame = window.frame
            let newOrigin = NSPoint(
                x: screenFrame.midX - winFrame.width / 2,
                y: screenFrame.midY - winFrame.height / 2
            )
            window.setFrameOrigin(newOrigin)
        }
    }
}

/// Hosting controller that reports the SwiftUI content's ideal size.
private final class ResponsiveHostingController<Content: View>: NSHostingController<Content> {
    var onSizeChanged: ((CGSize) -> Void)?

    override func viewDidLayout() {
        super.viewDidLayout()
        let ideal = view.fittingSize
        onSizeChanged?(ideal)
    }
}
