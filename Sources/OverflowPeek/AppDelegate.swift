import AppKit
import SwiftUI
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, StatusItemDelegate {
    let store = OverflowStore()
    let favVM = FavoriteAppsViewModel()
    private var statusItemController: StatusItemController!
    private var popoverController: PopoverController!
    private var settingsWindowController: SettingsWindowController?
    private var eventMonitor: Any?
    private var globalKeyMonitor: Any?
    private let statusMenu = NSMenu()
    private let loginManager = LaunchAtLoginManager()
    private let shortcutManager = KeyboardShortcutManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Initialize controllers
        statusItemController = StatusItemController()
        statusItemController.delegate = self
        popoverController = PopoverController(store: store, favVM: favVM, onOpenSettings: { [weak self] in
            self?.openSettings()
        }, onAppLaunched: { [weak self] in
            self?.popoverController.close()
        })

        configureEventMonitor()
        configureGlobalHotkey()
        showFirstLaunchIfNeeded()

        NotificationCenter.default.addObserver(
            forName: .shortcutDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.configureGlobalHotkey()
        }
    }

    private func showFirstLaunchIfNeeded() {
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "OverflowPeek.hasLaunchedBefore")
        guard !hasLaunchedBefore else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let alert = NSAlert()
            alert.messageText = "Welcome to Overflow Peek"
            alert.informativeText = """
            Quickly find and activate your menu bar utility apps.

            Overflow Peek shows likely menu bar utility apps from your running applications using heuristics. Pin your favorites to keep them at the top.

            Keyboard shortcuts:
            ↑↓ Navigate · Return Activate · Esc Close
            Cmd+Shift+M Toggle popover · Cmd+, Settings
            """
            alert.addButton(withTitle: "Got It")
            alert.icon = NSImage(systemSymbolName: "rectangle.stack.fill", accessibilityDescription: "")

            alert.runModal()
            UserDefaults.standard.set(true, forKey: "OverflowPeek.hasLaunchedBefore")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        [eventMonitor, globalKeyMonitor]
            .compactMap { $0 }
            .forEach { NSEvent.removeMonitor($0) }
    }

    // MARK: - StatusItemDelegate

    func statusItemLeftClicked(relativeTo rect: NSRect, in view: NSView) {
        guard let button = statusItemController.button else { return }
        popoverController.toggle(relativeTo: rect, of: button)
    }

    func statusItemRightClicked() {
        guard let button = statusItemController.button else { return }
        configureStatusMenu()
        statusMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
    }

    private func configureStatusMenu() {
        statusMenu.removeAllItems()

        // MARK: - App Section
        let launchAtLoginItem = NSMenuItem(
            title: loginManager.isEnabled ? "✓ Launch at Login" : "  Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLoginItem.target = self
        launchAtLoginItem.image = NSImage(systemSymbolName: loginManager.isEnabled ? "checkmark.circle.fill" : "circle", accessibilityDescription: "")
        launchAtLoginItem.image?.size = NSSize(width: 14, height: 14)
        statusMenu.addItem(launchAtLoginItem)

        statusMenu.addItem(NSMenuItem.separator())

        // MARK: - Actions Section
        let refreshItem = NSMenuItem(title: "Refresh List", action: #selector(refreshApps), keyEquivalent: "r")
        refreshItem.target = self
        refreshItem.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "")
        refreshItem.image?.size = NSSize(width: 14, height: 14)
        statusMenu.addItem(refreshItem)

        statusMenu.addItem(NSMenuItem.separator())

        // MARK: - Settings Section
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        settingsItem.image = NSImage(systemSymbolName: "gear", accessibilityDescription: "")
        settingsItem.image?.size = NSSize(width: 14, height: 14)
        statusMenu.addItem(settingsItem)

        let helpItem = NSMenuItem(title: "Help & Support", action: #selector(openHelp), keyEquivalent: "?")
        helpItem.target = self
        helpItem.image = NSImage(systemSymbolName: "questionmark.circle", accessibilityDescription: "")
        helpItem.image?.size = NSSize(width: 14, height: 14)
        statusMenu.addItem(helpItem)

        statusMenu.addItem(NSMenuItem.separator())

        // MARK: - System Section
        let restartItem = NSMenuItem(title: "Restart Overflow Peek", action: #selector(restartSelf), keyEquivalent: "")
        restartItem.target = self
        restartItem.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "")
        restartItem.image?.size = NSSize(width: 14, height: 14)
        statusMenu.addItem(restartItem)

        let quitItem = NSMenuItem(title: "Quit Overflow Peek", action: #selector(quitSelf), keyEquivalent: "q")
        quitItem.target = self
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: "")
        quitItem.image?.size = NSSize(width: 14, height: 14)
        statusMenu.addItem(quitItem)
    }

    private func configureEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.popoverController.isShown else { return }
            self.popoverController.close()
        }
    }

private func configureGlobalHotkey() {
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyMonitor = nil
        }

        HotKeyManager.shared.stop()

        let s = shortcutManager.togglePopoverShortcut

        HotKeyManager.shared.start(
            keyCode: keyCodeForChar(s.key),
            modifiers: carbonModifiers(from: s.modifiers)
        ) { [weak self] in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if self.popoverController.isShown {
                    self.popoverController.close()
                } else {
                    NSApp.activate(ignoringOtherApps: true)
                    self.popoverController.showAtScreenCenter()
                }
            }
        }

        // Backup path: NSEvent global key monitor. Some shortcuts get shadowed by other
        // processes' Carbon registrations even though our RegisterEventHotKey returns noErr.
        // This monitor sees raw keyDown events system-wide (requires Accessibility).
        let targetKeyCode = UInt16(keyCodeForChar(s.key))
        let targetModifiers = s.modifiers.eventModifiers
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            let masked = event.modifierFlags.intersection([.command, .shift, .option, .control])
            if event.keyCode == targetKeyCode && masked == targetModifiers {
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if self.popoverController.isShown {
                        self.popoverController.close()
                    } else {
                        NSApp.activate(ignoringOtherApps: true)
                        self.popoverController.showAtScreenCenter()
                    }
                }
            }
        }

        // The Carbon hotkey works WITHOUT Accessibility. The NSEvent global key monitor
        // above is just a backup. So we only nudge the user about Accessibility once,
        // ever — never repeatedly on every launch / shortcut change.
        let dismissedKey = "OverflowPeek.accessibilityPromptDismissed"
        if AXIsProcessTrusted() || UserDefaults.standard.bool(forKey: dismissedKey) {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let alert = NSAlert()
            alert.messageText = "Optional: Enable Accessibility"
            alert.informativeText = "Overflow Peek's global shortcut already works without any permissions.\n\nGranting Accessibility adds a fallback path that helps if another app ever shadows your shortcut. You won't be asked again."
            alert.addButton(withTitle: "Open Accessibility Settings")
            alert.addButton(withTitle: "Don't Ask Again")
            let response = alert.runModal()
            UserDefaults.standard.set(true, forKey: dismissedKey)
            if response == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
        }
    }

    private func keyCodeForChar(_ char: String) -> UInt32 {
        let map: [String: UInt32] = [
            "a": UInt32(kVK_ANSI_A), "b": UInt32(kVK_ANSI_B), "c": UInt32(kVK_ANSI_C),
            "d": UInt32(kVK_ANSI_D), "e": UInt32(kVK_ANSI_E), "f": UInt32(kVK_ANSI_F),
            "g": UInt32(kVK_ANSI_G), "h": UInt32(kVK_ANSI_H), "i": UInt32(kVK_ANSI_I),
            "j": UInt32(kVK_ANSI_J), "k": UInt32(kVK_ANSI_K), "l": UInt32(kVK_ANSI_L),
            "m": UInt32(kVK_ANSI_M), "n": UInt32(kVK_ANSI_N), "o": UInt32(kVK_ANSI_O),
            "p": UInt32(kVK_ANSI_P), "q": UInt32(kVK_ANSI_Q), "r": UInt32(kVK_ANSI_R),
            "s": UInt32(kVK_ANSI_S), "t": UInt32(kVK_ANSI_T), "u": UInt32(kVK_ANSI_U),
            "v": UInt32(kVK_ANSI_V), "w": UInt32(kVK_ANSI_W), "x": UInt32(kVK_ANSI_X),
            "y": UInt32(kVK_ANSI_Y), "z": UInt32(kVK_ANSI_Z),
            "0": UInt32(kVK_ANSI_0), "1": UInt32(kVK_ANSI_1), "2": UInt32(kVK_ANSI_2),
            "3": UInt32(kVK_ANSI_3), "4": UInt32(kVK_ANSI_4), "5": UInt32(kVK_ANSI_5),
            "6": UInt32(kVK_ANSI_6), "7": UInt32(kVK_ANSI_7), "8": UInt32(kVK_ANSI_8),
            "9": UInt32(kVK_ANSI_9),
            "return": UInt32(kVK_Return), "enter": UInt32(kVK_ANSI_KeypadEnter),
            "tab": UInt32(kVK_Tab), "space": UInt32(kVK_Space),
            "delete": UInt32(kVK_Delete), "backspace": UInt32(kVK_Delete),
            "escape": UInt32(kVK_Escape), "esc": UInt32(kVK_Escape),
            "up": UInt32(kVK_UpArrow), "down": UInt32(kVK_DownArrow),
            "left": UInt32(kVK_LeftArrow), "right": UInt32(kVK_RightArrow),
            "f1": UInt32(kVK_F1), "f2": UInt32(kVK_F2), "f3": UInt32(kVK_F3),
            "f4": UInt32(kVK_F4), "f5": UInt32(kVK_F5), "f6": UInt32(kVK_F6),
            "f7": UInt32(kVK_F7), "f8": UInt32(kVK_F8), "f9": UInt32(kVK_F9),
            "f10": UInt32(kVK_F10), "f11": UInt32(kVK_F11), "f12": UInt32(kVK_F12),
            "`": UInt32(kVK_ANSI_Grave), "-": UInt32(kVK_ANSI_Minus),
            "=": UInt32(kVK_ANSI_Equal), "[": UInt32(kVK_ANSI_LeftBracket),
            "]": UInt32(kVK_ANSI_RightBracket), "\\": UInt32(kVK_ANSI_Backslash),
            ";": UInt32(kVK_ANSI_Semicolon), "'": UInt32(kVK_ANSI_Quote),
            ",": UInt32(kVK_ANSI_Comma), ".": UInt32(kVK_ANSI_Period),
            "/": UInt32(kVK_ANSI_Slash),
            // Shifted variants of number row and punctuation, in case the
            // shortcut recorder stored the shift-modified character.
            "!": UInt32(kVK_ANSI_1), "@": UInt32(kVK_ANSI_2),
            "#": UInt32(kVK_ANSI_3), "$": UInt32(kVK_ANSI_4),
            "%": UInt32(kVK_ANSI_5), "^": UInt32(kVK_ANSI_6),
            "&": UInt32(kVK_ANSI_7), "*": UInt32(kVK_ANSI_8),
            "(": UInt32(kVK_ANSI_9), ")": UInt32(kVK_ANSI_0),
            "_": UInt32(kVK_ANSI_Minus), "+": UInt32(kVK_ANSI_Equal),
            "{": UInt32(kVK_ANSI_LeftBracket), "}": UInt32(kVK_ANSI_RightBracket),
            "|": UInt32(kVK_ANSI_Backslash), ":": UInt32(kVK_ANSI_Semicolon),
            "\"": UInt32(kVK_ANSI_Quote), "<": UInt32(kVK_ANSI_Comma),
            ">": UInt32(kVK_ANSI_Period), "?": UInt32(kVK_ANSI_Slash),
            "~": UInt32(kVK_ANSI_Grave)
        ]
        let lookup = char.lowercased()
        if let kc = map[lookup] { return kc }
        // Fallback: try original case (handles shifted symbols where lowercasing is a no-op anyway,
        // but also catches edge cases where the saved key may differ in case sensitivity).
        return map[char] ?? UInt32(kVK_ANSI_A)
    }

    private func carbonModifiers(from flags: KeyboardShortcut.ModifierFlags) -> UInt32 {
        var mods: UInt32 = 0
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        if flags.contains(.shift) { mods |= UInt32(shiftKey) }
        if flags.contains(.option) { mods |= UInt32(optionKey) }
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        return mods
    }


    @objc private func refreshApps() { store.refreshRunningApps() }

    @objc private func toggleLaunchAtLogin() {
        loginManager.toggle()
        configureStatusMenu()
    }

    @objc private func openSettings() {
        if settingsWindowController == nil {
            let contentView = SettingsView()
                .environmentObject(store)
                .environmentObject(favVM)
            settingsWindowController = SettingsWindowController(rootView: contentView)
        }
        settingsWindowController?.show()
    }

    @objc private func openHelp() {
        let alert = NSAlert()
        alert.messageText = "Overflow Peek"
        alert.informativeText = """
        Use the menu bar icon (left-click) or your configured global shortcut to open the launcher.

        ↑↓ Navigate · Return Activate · Esc Close
        ⌘, Settings · ⌘Q Quit
        """
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func restartSelf() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = [Bundle.main.bundlePath]
        try? task.run()
        NSApp.terminate(nil)
    }

    @objc private func quitSelf() { NSApp.terminate(nil) }
}

// MARK: - Settings Window Controller
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow

    init<V: View>(rootView: V) {
        let hosting = NSHostingController(rootView: rootView)
        window = NSWindow(contentViewController: hosting)
        window.title = "Overflow Peek Settings"
        window.setContentSize(NSSize(width: 540, height: 400))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.center()
        window.isReleasedWhenClosed = false
        super.init()
        window.delegate = self
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        // Keep the controller alive; window persists across opens
    }
}
