import SwiftUI

// MARK: - Popover View
struct PopoverView: View {
    @EnvironmentObject var store: OverflowStore
    @EnvironmentObject var favVM: FavoriteAppsViewModel
    @ObservedObject private var quickActions = QuickActionsManager.shared
    @State private var selectedIndex: Int = 0
    @State private var draggingFavID: String?
    @FocusState private var searchFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    let onOpenSettings: () -> Void
    let onAppLaunched: () -> Void

    private var allRows: [AppDetectionResult] {
        let pinned = store.pinnedAppItems
        let recent = store.recentlyActiveItems.filter { !pinned.contains($0) }
        let other = store.otherApps.filter { !pinned.contains($0) && !recent.contains($0) }
        return pinned + recent + other
    }

    var body: some View {
        VStack(spacing: 0) {
            titleHeader
            searchBar
            Divider()
            contentArea
            Divider()
            footerBar
        }
        .frame(width: 320)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            store.refreshRunningApps()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                searchFocused = true
            }
        }
        .onChange(of: store.searchQuery) { _ in selectedIndex = 0 }
        .background(KeyHandlingView(
            onDownArrow: { moveSelection(by: 1) },
            onUpArrow: { moveSelection(by: -1) },
            onReturn: { activateSelected() },
            onEscape: { closePopover() }
        ))
    }

    // MARK: - Title Header
    private var titleHeader: some View {
        HStack {
            Text("OverflowPeek")
                .font(.custom("New York", size: 18))
                .fontWeight(.medium)
                .tracking(0.6)
                .foregroundStyle(.primary.opacity(0.85))
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 2)
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 12))
            TextField("Search apps...", text: $store.searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($searchFocused)
            if !store.searchQuery.isEmpty {
                Button(action: { store.searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
        .padding(10)
    }

    // MARK: - Content Area
    @ViewBuilder
    private var contentArea: some View {
        if store.isLoading {
            loadingView
        } else if allRows.isEmpty && store.searchQuery.isEmpty {
            EmptyStateView(onRefresh: { store.refreshRunningApps() })
        } else if store.filteredApps.isEmpty {
            noSearchResultsView
        } else {
            appListView
}
}

// MARK: - Favorite Row (in popover)
struct PopoverFavoriteRow: View {
    let fav: FavoriteApp
    @ObservedObject var favVM: FavoriteAppsViewModel
    var onLaunched: (() -> Void)?
    @State private var isHovered = false

    private var running: Bool { favVM.isRunning(fav) }

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if let icon = NSWorkspace.shared.icon(forFile: fav.path) as NSImage? {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .cornerRadius(4)
                } else {
                    Image(systemName: "star.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(fav.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(running ? "Running" : "Not running")
                    .font(.system(size: 10))
                    .foregroundStyle(running ? .green : .secondary)
            }

            Spacer()

            if isHovered {
                HStack(spacing: 6) {
                    if running {
                        Button(action: { favVM.terminateApp(fav) }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .help("Quit this app")
                    }
                    Button(action: { favVM.launchApp(fav) }) {
                        Image(systemName: running ? "arrow.up.forward.app.fill" : "play.fill")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .help(running ? "Activate" : "Launch")
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(height: 36)
        .contentShape(Rectangle())
        .onTapGesture { favVM.launchApp(fav); onLaunched?() }
        .onHover { isHovered = $0 }
    }
}

    private var loadingView: some View {
        VStack(spacing: 10) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Scanning running apps...")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private var noSearchResultsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
            Text("No matching apps")
                .font(.system(size: 13, weight: .semibold))
            Text("Try a different search term")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    @ViewBuilder
    private var appListView: some View {
        let pinned = store.filteredApps.filter { store.pinnedBundleIDs.contains($0.bundleIdentifier) }
        let recent = store.filteredApps.filter {
            !store.pinnedBundleIDs.contains($0.bundleIdentifier) &&
            store.recentlyActiveBundleIDs.contains($0.bundleIdentifier)
        }
        let other = store.filteredApps.filter {
            !store.pinnedBundleIDs.contains($0.bundleIdentifier) &&
            !store.recentlyActiveBundleIDs.contains($0.bundleIdentifier)
        }

        let sectionCount = (pinned.isEmpty ? 0 : 1) + (recent.isEmpty ? 0 : 1) + (other.isEmpty ? 0 : 1)
        let totalRows = pinned.count + recent.count + other.count
        let totalHeight = CGFloat(sectionCount) * 26 + CGFloat(totalRows) * 36
        let needsScroll = totalHeight > 430

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !favVM.favorites.isEmpty {
                    SectionHeader(title: "FAVORITES", icon: "star.fill", count: favVM.favorites.count)
                    ForEach(Array(favVM.favorites.enumerated()), id: \.element.id) { index, fav in
                        PopoverFavoriteRow(fav: fav, favVM: favVM, onLaunched: onAppLaunched)
                            .opacity(draggingFavID == fav.id ? 0.5 : 1.0)
                            .onDrag {
                                draggingFavID = fav.id
                                return NSItemProvider(object: fav.id as NSString)
                            }
                            .onDrop(
                                of: [.text],
                                delegate: FavoriteDropDelegate(
                                    favID: fav.id,
                                    index: index,
                                    favorites: favVM.favorites,
                                    onReorder: { sourceID, targetID in
                                        guard let fromIdx = favVM.favorites.firstIndex(where: { $0.id == sourceID }),
                                              let toIdx = favVM.favorites.firstIndex(where: { $0.id == targetID }) else { return }
                                        favVM.moveFavorite(from: IndexSet(integer: fromIdx), to: toIdx)
                                    },
                                    onDragEnd: { draggingFavID = nil }
                                )
                            )
                    }
                }

                if !pinned.isEmpty {
                    SectionHeader(title: "PINNED", icon: "pin.fill", count: pinned.count)
                    ForEach(Array(pinned.enumerated()), id: \.element.id) { index, app in
                        AppRowView(
                            app: app,
                            isSelected: isSelected(index),
                            onPin: nil,
                            onUnpin: { store.unpinApp(app.bundleIdentifier) },
                            onQuit: { store.quitApp(app.bundleIdentifier) },
                            onHide: { store.excludeApp(app.bundleIdentifier) },
                            onDetails: nil
                        )
                        .onTapGesture { store.activateApp(app.bundleIdentifier); onAppLaunched() }
                    }
                }

                if !recent.isEmpty {
                    SectionHeader(title: "RECENTLY ACTIVE", icon: "clock.fill", count: nil)
                    ForEach(Array(recent.enumerated()), id: \.element.id) { index, app in
                        AppRowView(
                            app: app,
                            isSelected: isSelected(pinned.count + index),
                            onPin: { store.pinApp(app.bundleIdentifier) },
                            onUnpin: nil,
                            onQuit: { store.quitApp(app.bundleIdentifier) },
                            onHide: { store.excludeApp(app.bundleIdentifier) },
                            onDetails: nil
                        )
                        .onTapGesture { store.activateApp(app.bundleIdentifier); onAppLaunched() }
                    }
                }

                if !other.isEmpty {
                    SectionHeader(title: "RUNNING", icon: "app.dashed", count: nil)
                    ForEach(Array(other.enumerated()), id: \.element.id) { index, app in
                        AppRowView(
                            app: app,
                            isSelected: isSelected(pinned.count + recent.count + index),
                            onPin: { store.pinApp(app.bundleIdentifier) },
                            onUnpin: nil,
                            onQuit: { store.quitApp(app.bundleIdentifier) },
                            onHide: { store.excludeApp(app.bundleIdentifier) },
                            onDetails: nil
                        )
                        .onTapGesture { store.activateApp(app.bundleIdentifier); onAppLaunched() }
                    }
                }
            }
        }
        .scrollDisabled(!needsScroll)
        .frame(maxHeight: needsScroll ? 430 : nil)
    }

    // MARK: - Footer
    private var footerBar: some View {
        HStack {
            HStack(spacing: 4) {
                Text("\(store.filteredApps.count) app\(store.filteredApps.count == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                if store.pinnedBundleIDs.count > 0 {
                    Text("· \(store.pinnedBundleIDs.count) pinned")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            ForEach(quickActions.paths, id: \.self) { path in
                if FileManager.default.fileExists(atPath: path) {
                    Button(action: { openApp(at: path) }) {
                        Image(nsImage: iconForApp(path))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)
                    .help("Open \(QuickActionsManager.displayName(for: path))")
                }
            }
            Button(action: { store.refreshRunningApps() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Refresh running apps (Cmd+R)")
            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings (Cmd+,)")
        }
.padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Helpers
    private func isSelected(_ index: Int) -> Bool { selectedIndex == index }

    private func moveSelection(by delta: Int) {
        let maxIndex = allRows.count - 1
        guard maxIndex >= 0 else { return }
        selectedIndex = max(0, min(maxIndex, selectedIndex + delta))
    }

    private func activateSelected() {
        guard selectedIndex >= 0, selectedIndex < allRows.count else { return }
        store.activateApp(allRows[selectedIndex].bundleIdentifier)
    }

    private func closePopover() {
        guard let window = NSApp.keyWindow else { return }
        window.performClose(nil)
    }

    // MARK: - App Launchers
    private func openApp(at path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if error != nil {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

// MARK: - Favorite Drag and Drop Delegate
struct FavoriteDropDelegate: DropDelegate {
    let favID: String
    let index: Int
    let favorites: [FavoriteApp]
    let onReorder: (String, String) -> Void
    let onDragEnd: () -> Void

    func dropEntered(info: DropInfo) {
        guard let provider = info.itemProviders(for: [.text]).first else { return }
        _ = provider.loadObject(ofClass: NSString.self) { id, _ in
            guard let sourceID = id as? String, sourceID != favID else { return }
            DispatchQueue.main.async {
                onReorder(sourceID, favID)
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        onDragEnd()
        return true
    }

    func dropExited(info: DropInfo) {}
}

private func iconForApp(_ path: String) -> NSImage {
    NSWorkspace.shared.icon(forFile: path)
}

// MARK: - Keyboard Handling (macOS 13+ compatible)
struct KeyHandlingView: NSViewRepresentable {
    var onDownArrow: () -> Void
    var onUpArrow: () -> Void
    var onReturn: () -> Void
    var onEscape: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = KeyCaptureNSView()
        view.onKeyEvent = { event in
            switch event.keyCode {
            case 125: onDownArrow()
            case 126: onUpArrow()
            case 36: onReturn()
            case 53: onEscape()
            default: break
            }
        }
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private class KeyCaptureNSView: NSView {
    var onKeyEvent: ((NSEvent) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        onKeyEvent?(event)
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    let icon: String
    var count: Int?
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                if let count = count {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let onRefresh: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                Text("No running applications detected")
                    .font(.system(size: 13, weight: .semibold))
                Text("Open any regular Mac application to see it listed here.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)

            Button(action: onRefresh) {
                Text("Scan Again")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding(.horizontal, 16)
    }
}
