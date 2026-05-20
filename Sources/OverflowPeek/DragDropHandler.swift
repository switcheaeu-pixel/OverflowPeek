import AppKit
import Foundation
import SwiftUI

class DropView: NSView {
    var onDrop: ((NSRunningApplication) -> Void)?
    var onDragEnter: (() -> Void)?
    var onDragExit: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        registerForDraggedTypes([.string, NSPasteboard.PasteboardType.tiff])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onDragEnter?()
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onDragExit?()
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard

        if let types = pasteboard.types, types.contains(.string) {
            if let bundleID = pasteboard.string(forType: .string) {
                if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) {
                    onDrop?(app)
                    return true
                }
            }
        }

        // Try to find app by bundle ID in pasteboard content
        let workspace = NSWorkspace.shared
        for app in workspace.runningApplications {
            if let bundleID = app.bundleIdentifier {
                if pasteboard.string(forType: .string)?.contains(bundleID) ?? false {
                    onDrop?(app)
                    return true
                }
            }
        }

        return false
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }
}

// MARK: - NSView Representable for SwiftUI
struct DropZoneView: NSViewRepresentable {
    var onDrop: (NSRunningApplication) -> Void
    var onDragEnter: () -> Void = {}
    var onDragExit: () -> Void = {}

    func makeNSView(context: Context) -> DropView {
        let view = DropView()
        view.registerForDraggedTypes([.string, .tiff, NSPasteboard.PasteboardType(rawValue: "public.app-bundle")])
        view.onDrop = onDrop
        view.onDragEnter = onDragEnter
        view.onDragExit = onDragExit
        return view
    }

    func updateNSView(_ nsView: DropView, context: Context) {
        nsView.onDrop = onDrop
        nsView.onDragEnter = onDragEnter
        nsView.onDragExit = onDragExit
    }
}
