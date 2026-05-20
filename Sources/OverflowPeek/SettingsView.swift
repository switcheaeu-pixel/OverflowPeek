import SwiftUI
import ServiceManagement
import AppKit

struct SettingsView: View {
    @EnvironmentObject var store: OverflowStore
    @EnvironmentObject var favVM: FavoriteAppsViewModel
    @StateObject private var loginManager = LaunchAtLoginManager()
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Custom Title Bar
            HStack(spacing: 12) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Overflow Peek Settings")
                        .font(.system(size: 15, weight: .bold))
                    Text("Customize your experience")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            TabView(selection: $selectedTab) {
                GeneralTab(loginManager: loginManager)
                    .environmentObject(store)
                    .tabItem { Label("General", systemImage: "gearshape") }
                    .tag(0)

                FavoriteAppsTab()
                    .tabItem { Label("Favorite Apps", systemImage: "star.fill") }
                    .tag(1)

                AboutTab()
                    .tabItem { Label("About", systemImage: "info.circle") }
                    .tag(2)
            }
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
        }
        .frame(width: 540, height: 420)
        .onAppear { store.refreshRunningApps() }
    }
}

// MARK: - General Tab
private struct GeneralTab: View {
    @EnvironmentObject var store: OverflowStore
    @ObservedObject var loginManager: LaunchAtLoginManager
    @ObservedObject private var quickActions = QuickActionsManager.shared
    @State private var showKeyboardShortcuts = false

    var body: some View {
        Form {
            Section("Behaviour") {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Launch at Login", isOn: Binding(
                        get: { loginManager.isEnabled },
                        set: { _ in loginManager.toggle() }
                    ))
                    settingCaption("Start Overflow Peek automatically when you log in to macOS.")
                }
            }

            Section("Auto-Refresh") {
                VStack(alignment: .leading, spacing: 4) {
                    LabeledContent("Refresh interval") {
                        Text("Every 10s")
                            .foregroundStyle(.secondary)
                    }
                    settingCaption("How often the list of running menu bar apps is re-scanned in the background.")
                }
            }

            Section("Running Apps") {
                VStack(alignment: .leading, spacing: 4) {
                    LabeledContent("Running apps") {
                        Text("\(store.allApps.count)")
                            .foregroundStyle(.secondary)
                    }
                    settingCaption("Total number of applications currently detected as running.")
                }
                VStack(alignment: .leading, spacing: 4) {
                    Button("Refresh Now") { store.refreshRunningApps() }
                        .buttonStyle(.bordered)
                    settingCaption("Force an immediate re-scan instead of waiting for the next auto-refresh.")
                }
            }

            Section {
                if quickActions.paths.isEmpty {
                    Text("No quick actions. Click \"Add App…\" to choose one.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(quickActions.paths.enumerated()), id: \.element) { index, path in
                        HStack(spacing: 8) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                                .resizable()
                                .frame(width: 20, height: 20)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(QuickActionsManager.displayName(for: path))
                                    .font(.system(size: 12, weight: .medium))
                                Text(path)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            Button {
                                quickActions.remove(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            .help("Remove from quick actions")
                        }
                    }
                }
                HStack {
                    Button("Add App…") { pickQuickAction() }
                        .buttonStyle(.bordered)
                    Button("Reset to Defaults") { quickActions.resetToDefaults() }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Quick Actions")
            } footer: {
                Text("Apps shown as clickable icons at the bottom of the launcher window.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Section("Keyboard Shortcuts") {
                VStack(alignment: .leading, spacing: 4) {
                    Button("Manage Shortcuts...") { showKeyboardShortcuts = true }
                        .buttonStyle(.bordered)
                    settingCaption("Customize the global hotkey that opens the floating launcher window.")
                }
            }
        }
        .formStyle(.grouped)
        .padding(10)
        .sheet(isPresented: $showKeyboardShortcuts) {
            KeyboardShortcutSettingsView()
        }
    }

    @ViewBuilder
    private func settingCaption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func pickQuickAction() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = "Choose an application to add as a quick action"
        panel.prompt = "Add"
        if panel.runModal() == .OK, let url = panel.url {
            quickActions.add(url.path)
        }
    }
}

// MARK: - About Tab
private struct AboutTab: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(.blue)

            VStack(spacing: 4) {
                Text("Overflow Peek")
                    .font(.system(size: 18, weight: .bold))
                Text("Version 2.0")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Divider().frame(width: 160)

            VStack(alignment: .leading, spacing: 8) {
                FeatureRow(icon: "rectangle.stack", color: .blue, text: "Detects likely menu bar utility apps from running applications")
                FeatureRow(icon: "pin.fill", color: .orange, text: "Pin your favorites for quick access at the top")
                FeatureRow(icon: "magnifyingglass", color: .purple, text: "Real-time search across all detected apps")
                FeatureRow(icon: "keyboard", color: .green, text: "Full keyboard navigation support")
            }

            Spacer()

            VStack(spacing: 4) {
                Text("Uses heuristics, not icon detection.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Text("Built with SwiftUI + AppKit for macOS 13+")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Favorite Apps Tab
private struct FavoriteAppsTab: View {
    @EnvironmentObject var favVM: FavoriteAppsViewModel
    @State private var showAddError = false
    @State private var addErrorMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Toolbar
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Favorite Apps")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Pin apps you launch often. They appear at the top of the launcher window for one-click access.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button(action: openAppPicker) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Add App")
                            .font(.system(size: 12))
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            if favVM.favorites.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(favVM.favorites) { fav in
                        FavoriteRow(fav: fav, favVM: favVM)
                            .contextMenu {
                                Button("Open") { favVM.launchApp(fav) }
                                if favVM.isRunning(fav) {
                                    Button("Close") { favVM.terminateApp(fav) }
                                }
                                Divider()
                                Button("Remove from Favorites", role: .destructive) {
                                    favVM.removeApp(fav)
                                }
                            }
                    }
                }
                .listStyle(.inset)
            }

            Divider()

            HStack {
                Text("\(favVM.favorites.count) favorite\(favVM.favorites.count == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
        .alert("Cannot Add App", isPresented: $showAddError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(addErrorMessage)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "star.slash")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("No favorite apps yet")
                .font(.system(size: 13, weight: .semibold))
            Text("Click \"Add App\" to choose applications from your /Applications folder.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button(action: openAppPicker) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                    Text("Add First App")
                        .font(.system(size: 12))
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func openAppPicker() {
        let panel = NSOpenPanel()
        panel.title = "Choose an Application"
        panel.message = "Select a .app bundle to add to your favorites."
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.treatsFilePackagesAsDirectories = false

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            guard url.pathExtension == "app" || Bundle(url: url)?.bundleIdentifier != nil else {
                addErrorMessage = "The selected file is not a valid application bundle."
                showAddError = true
                return
            }

            favVM.addApp(from: url)
        }
    }
}

// MARK: - Favorite Row
private struct FavoriteRow: View {
    let fav: FavoriteApp
    @ObservedObject var favVM: FavoriteAppsViewModel
    @State private var isHovered = false

    private var running: Bool { favVM.isRunning(fav) }

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let icon = NSWorkspace.shared.icon(forFile: fav.path) as NSImage? {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 28, height: 28)
                        .cornerRadius(5)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(fav.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(running ? "Running" : "Not Running")
                    .font(.system(size: 10))
                    .foregroundStyle(running ? Color.green : Color.secondary)
            }

            Spacer()

            if isHovered || running {
                HStack(spacing: 4) {
                    Button(action: { favVM.launchApp(fav) }) {
                        Image(systemName: running ? "arrow.up.forward.app.fill" : "play.fill")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .help(running ? "Activate" : "Launch")

                    if running {
                        Button(action: { favVM.terminateApp(fav) }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .help("Quit")
                    }

                    Button(action: { favVM.removeApp(fav) }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Remove from Favorites")
                }
            }
        }
        .padding(.vertical, 2)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Feature Row
private struct FeatureRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 16)
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }
}
