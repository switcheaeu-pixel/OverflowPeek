import AppKit

/// Manages the menu bar status item with a custom bar-chart template icon.
@MainActor
final class StatusItemController {
    private let statusItem: NSStatusItem
    var button: NSStatusBarButton? { statusItem.button }

    weak var delegate: StatusItemDelegate?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        configureButton()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }

        button.image = makeMenuBarIcon()
        button.image?.isTemplate = true
        button.toolTip = "Overflow Peek — Show running apps"
        button.target = self
        button.action = #selector(statusBarButtonClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        switch event.type {
        case .rightMouseUp:
            delegate?.statusItemRightClicked()
        default:
            delegate?.statusItemLeftClicked(relativeTo: sender.bounds, in: sender)
        }
    }

    private func makeMenuBarIcon() -> NSImage {
        // 2x2 grid of rounded tiles with one tile "peeking" out from the back-top-right —
        // matches the dock icon's visual language. Template so it inherits menu bar tint.
        let size = NSSize(width: 18, height: 18)
        let icon = NSImage(size: size)
        icon.isTemplate = true
        icon.lockFocus()

        NSColor.black.setFill()

        // Peeking back card (top-right, slightly offset & dimmer)
        NSColor.black.withAlphaComponent(0.35).setFill()
        NSBezierPath(roundedRect: NSRect(x: 11.5, y: 11.5, width: 5, height: 5),
                     xRadius: 1.4, yRadius: 1.4).fill()

        // Foreground 2x2 grid
        NSColor.black.setFill()
        let tile: CGFloat = 5
        let gap:  CGFloat = 1.5
        let origin = CGPoint(x: 2, y: 2)
        for row in 0..<2 {
            for col in 0..<2 {
                let x = origin.x + CGFloat(col) * (tile + gap)
                let y = origin.y + CGFloat(row) * (tile + gap)
                NSBezierPath(roundedRect: NSRect(x: x, y: y, width: tile, height: tile),
                             xRadius: 1.4, yRadius: 1.4).fill()
            }
        }

        icon.unlockFocus()
        return icon
    }
}

protocol StatusItemDelegate: AnyObject {
    func statusItemLeftClicked(relativeTo rect: NSRect, in view: NSView)
    func statusItemRightClicked()
}
