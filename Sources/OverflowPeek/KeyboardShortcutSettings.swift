import SwiftUI
import AppKit

extension Notification.Name {
    static let shortcutDidChange = Notification.Name("OverflowPeek.shortcutDidChange")
}

// MARK: - Keyboard Shortcut Manager
@MainActor
class KeyboardShortcutManager: ObservableObject {
    static let shared = KeyboardShortcutManager()
    
    @Published var togglePopoverShortcut: KeyboardShortcut
    
    private let toggleShortcutKey = "OverflowPeek.toggleShortcut"
    
    init() {
        // Load saved shortcut or use default (Cmd+Shift+M)
        if let data = UserDefaults.standard.data(forKey: toggleShortcutKey),
           let decoded = try? JSONDecoder().decode(KeyboardShortcut.self, from: data) {
            self.togglePopoverShortcut = decoded
        } else {
            self.togglePopoverShortcut = KeyboardShortcut(key: "m", modifiers: [.command, .shift])
        }
    }
    
    func saveShortcut(_ shortcut: KeyboardShortcut) {
        self.togglePopoverShortcut = shortcut
        if let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: toggleShortcutKey)
        }
        NotificationCenter.default.post(name: .shortcutDidChange, object: nil)
    }
}

// MARK: - Keyboard Shortcut Model
struct KeyboardShortcut: Codable, Equatable {
    var key: String
    var modifiers: ModifierFlags
    
    struct ModifierFlags: OptionSet, Codable, Equatable {
        let rawValue: Int
        
        static let command = ModifierFlags(rawValue: 1 << 0)
        static let shift = ModifierFlags(rawValue: 1 << 1)
        static let option = ModifierFlags(rawValue: 1 << 2)
        static let control = ModifierFlags(rawValue: 1 << 3)
        
        var eventModifiers: NSEvent.ModifierFlags {
            var flags: NSEvent.ModifierFlags = []
            if contains(.command) { flags.insert(.command) }
            if contains(.shift) { flags.insert(.shift) }
            if contains(.option) { flags.insert(.option) }
            if contains(.control) { flags.insert(.control) }
            return flags
        }
        
        var displayString: String {
            var parts: [String] = []
            if contains(.control) { parts.append("⌃") }
            if contains(.option) { parts.append("⌥") }
            if contains(.shift) { parts.append("⇧") }
            if contains(.command) { parts.append("⌘") }
            return parts.joined()
        }
    }
    
    var displayString: String {
        "\(modifiers.displayString)\(key.uppercased())"
    }
}

// MARK: - Keyboard Shortcut Recorder View
struct KeyboardShortcutRecorder: View {
    @Binding var shortcut: KeyboardShortcut
    @State private var isRecording = false
    @State private var temporaryShortcut: KeyboardShortcut?
    
    var body: some View {
        HStack(spacing: 8) {
            Text(isRecording ? "Press keys..." : shortcut.displayString)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(isRecording ? .blue : .primary)
                .frame(minWidth: 80, alignment: .center)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isRecording ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(isRecording ? Color.blue : Color.clear, lineWidth: 2)
                )
            
            if isRecording {
                Button("Cancel") {
                    isRecording = false
                    temporaryShortcut = nil
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.system(size: 11))
            } else {
                Button("Record") {
                    isRecording = true
                    temporaryShortcut = nil
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                .font(.system(size: 11))
                
                Button("Reset") {
                    shortcut = KeyboardShortcut(key: "m", modifiers: [.command, .shift])
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.system(size: 11))
            }
        }
        .background(KeyEventHandler(isRecording: $isRecording, shortcut: $shortcut))
    }
}

// MARK: - Key Event Handler
private struct KeyEventHandler: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var shortcut: KeyboardShortcut
    
    func makeNSView(context: Context) -> NSView {
        let view = KeyCaptureView()
        view.onKeyEvent = { event in
            guard isRecording else { return }
            
            let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
            guard !modifiers.isEmpty else { return }
            
            if let characters = event.charactersIgnoringModifiers, !characters.isEmpty {
                var shortcutModifiers = KeyboardShortcut.ModifierFlags()
                if modifiers.contains(.command) { shortcutModifiers.insert(.command) }
                if modifiers.contains(.shift) { shortcutModifiers.insert(.shift) }
                if modifiers.contains(.option) { shortcutModifiers.insert(.option) }
                if modifiers.contains(.control) { shortcutModifiers.insert(.control) }
                
                let newShortcut = KeyboardShortcut(key: characters.lowercased(), modifiers: shortcutModifiers)
                shortcut = newShortcut
                isRecording = false
            }
        }
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if isRecording {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

private class KeyCaptureView: NSView {
    var onKeyEvent: ((NSEvent) -> Void)?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        onKeyEvent?(event)
    }
    
    override func flagsChanged(with event: NSEvent) {
        // Ignore just modifier key presses
    }
}

// MARK: - Settings View with Keyboard Shortcut
struct KeyboardShortcutSettingsView: View {
    @ObservedObject var shortcutManager = KeyboardShortcutManager.shared
    @Environment(\.dismiss) var dismiss
    
    private var windowBackgroundColor: Color {
        return Color(nsColor: .windowBackgroundColor)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Keyboard Shortcuts")
                        .font(.system(size: 16, weight: .bold))
                    Text("Customize shortcuts for Overflow Peek")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
            }
            .padding(16)
            
            Divider()
            
            // Settings content
            Form {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Toggle Overflow Peek")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Show or hide the Overflow Peek panel")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        KeyboardShortcutRecorder(shortcut: Binding(
                            get: { shortcutManager.togglePopoverShortcut },
                            set: { shortcutManager.saveShortcut($0) }
                        ))
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Global Shortcuts")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        InfoRow(
                            icon: "arrow.up.arrow.down",
                            title: "Navigate",
                            shortcut: "↑↓ or Tab"
                        )
                        InfoRow(
                            icon: "return",
                            title: "Activate App",
                            shortcut: "Return or Double-click"
                        )
                        InfoRow(
                            icon: "escape",
                            title: "Close Panel",
                            shortcut: "Esc"
                        )
                        InfoRow(
                            icon: "magnifyingglass",
                            title: "Focus Search",
                            shortcut: "⌘F"
                        )
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Panel Shortcuts")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(width: 500, height: 400)
        .background(windowBackgroundColor)
    }
}

// MARK: - Info Row
private struct InfoRow: View {
    let icon: String
    let title: String
    let shortcut: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.blue)
                .frame(width: 20)
            
            Text(title)
                .font(.system(size: 12))
            
            Spacer()
            
            Text(shortcut)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }
}
