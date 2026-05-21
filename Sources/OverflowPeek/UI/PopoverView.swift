import SwiftUI
import Darwin

// MARK: - Popover View
struct PopoverView: View {
    @EnvironmentObject var store: OverflowStore
    @EnvironmentObject var favVM: FavoriteAppsViewModel
    @ObservedObject private var quickActions = QuickActionsManager.shared
    @State private var selectedIndex: Int = 0
    @State private var draggingFavID: String?
    @State private var opened: Bool = false
    @State private var localKeyMonitor: Any? = nil
    @State private var memoryUsed: UInt64 = 0
    @State private var memoryTotal: UInt64 = 0
    @FocusState private var searchFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    let onOpenSettings: () -> Void
    let onAppLaunched: () -> Void

    // MARK: - Mode helpers
    private var isSwitcher: Bool { store.invocationMode == .switcher }

    /// Live-filtered favorites for the switcher strip. Filters by name (case-insensitive)
    /// against `store.searchQuery`. Manager mode is unaffected.
    private var filteredFavorites: [FavoriteApp] {
        let q = store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return favVM.favorites }
        let lower = q.lowercased()
        return favVM.favorites.filter { $0.name.lowercased().contains(lower) }
    }

    /// A row that can be selected with the keyboard and acted on with Return / Cmd+digit.
    /// Unifies AppDetectionResult-backed rows and favorite-backed rows behind a single action.
    private struct SelectableRow: Identifiable {
        let id: String
        let action: () -> Void
    }

    /// Flat list of selectable rows in the same visual order they appear on screen.
    /// Switcher mode: Open Now → Favorites → Recently Active.
    /// Manager mode: Favorites → Pinned → Recently Active → Other Running.
    private var selectableRows: [SelectableRow] {
        var rows: [SelectableRow] = []
        let favIDs = Set(favVM.favorites.compactMap { $0.bundleIdentifier })

        if isSwitcher {
            // Switcher mode (global shortcut) shows favorites only, filtered by search.
            for fav in filteredFavorites {
                rows.append(SelectableRow(id: "fav:\(fav.id)") {
                    favVM.launchApp(fav)
                    onAppLaunched()
                })
            }
        } else {
            for fav in favVM.favorites {
                rows.append(SelectableRow(id: "fav:\(fav.id)") {
                    favVM.launchApp(fav)
                    onAppLaunched()
                })
            }
            for app in store.pinnedAppItems {
                rows.append(SelectableRow(id: "pin:\(app.bundleIdentifier)") {
                    store.activateApp(app.bundleIdentifier)
                    onAppLaunched()
                })
            }
            for app in store.otherApps where !store.pinnedBundleIDs.contains(app.bundleIdentifier) {
                rows.append(SelectableRow(id: "other:\(app.bundleIdentifier)") {
                    store.activateApp(app.bundleIdentifier)
                    onAppLaunched()
                })
            }
        }
        return rows
    }

    /// Kept for source-compat with callers that reference AppDetectionResult-only rows.
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
            softDivider
            contentArea
            softDivider
            footerBar
        }
        .frame(width: isSwitcher ? 600 : 320)
        .background(Color(nsColor: .windowBackgroundColor))
        // Open animation: fade + tiny zoom-in. Lightweight, native-feeling.
        .opacity(opened ? 1.0 : 0.0)
        .scaleEffect(opened ? 1.0 : 0.97)
        .onAppear {
            store.refreshRunningApps()
            fetchMemoryStats()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                searchFocused = true
            }
            opened = false
            withAnimation(.easeOut(duration: 0.16)) { opened = true }
            installLocalKeyMonitor()
        }
        .onDisappear { removeLocalKeyMonitor() }
        .onChange(of: store.searchQuery) { _ in selectedIndex = 0 }
        .onChange(of: store.filteredApps.count) { _ in fetchMemoryStats() }
    }

    // MARK: - Keyboard handling
    /// Installs an NSEvent local monitor that intercepts navigation keys *before*
    /// they reach the focused search field. Returning nil from the monitor stops
    /// propagation so the TextField never sees them.
    private func installLocalKeyMonitor() {
        removeLocalKeyMonitor()
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Option+1..9 quick jump — read keyCode (not characters) so the option
            // modifier doesn't turn the digit into a typographic glyph like ¡ or ™.
            if event.modifierFlags.contains(.option) {
                let digitForKeyCode: [UInt16: Int] = [
                    18: 1, 19: 2, 20: 3, 21: 4, 23: 5,
                    22: 6, 26: 7, 28: 8, 25: 9
                ]
                if let digit = digitForKeyCode[event.keyCode] {
                    activateRow(at: digit - 1)
                    return nil
                }
            }
            // In switcher (horizontal strip) mode, all arrows move by one item.
            // Manager (list) mode keeps single-step up/down and ignores
            // left/right so cursor movement still works in the search field.
            switch event.keyCode {
            case 125: // down
                moveSelection(by: isSwitcher ? 1 : 1); return nil
            case 126: // up
                moveSelection(by: isSwitcher ? -1 : -1); return nil
            case 123: // left
                if isSwitcher { moveSelection(by: -1); return nil }
                return event
            case 124: // right
                if isSwitcher { moveSelection(by: 1); return nil }
                return event
            case 36, 76: activateSelected(); return nil   // return / numpad enter
            case 53: closePopover(); return nil           // escape
            default: return event
            }
        }
    }

    private func removeLocalKeyMonitor() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
    }

    private var softDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.1))
            .frame(height: 1)
            .padding(.horizontal, 10)
    }

    // MARK: - Title Header
    @ViewBuilder
    private var titleHeader: some View {
        if !isSwitcher {
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
        .padding(.vertical, isSwitcher ? 5 : 7)
        .background(
            isSwitcher
                ? Color.primary.opacity(0.06)
                : Color(nsColor: .controlBackgroundColor)
        )
        .cornerRadius(6)
        .padding(isSwitcher ? 8 : 10)
    }

    // MARK: - Content Area
    @ViewBuilder
    private var contentArea: some View {
        if store.isLoading {
            loadingView
        } else if isSwitcher {
            // Switcher mode reads from favorites, not the running-apps list, so
            // it has its own empty/no-results gating.
            if favVM.favorites.isEmpty {
                switcherEmptyState
            } else if filteredFavorites.isEmpty {
                noSearchResultsView
            } else {
                switcherHorizontalStrip
            }
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
    var isSelected: Bool = false
    var quickJumpIndex: Int? = nil
    @State private var isHovered = false

    private var running: Bool { favVM.isRunning(fav) }

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if let icon = NSWorkspace.shared.icon(forFile: fav.path) as NSImage? {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 28, height: 28)
                        .cornerRadius(5)
                } else {
                    Image(systemName: "star.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
            }

            HStack(spacing: 5) {
                Circle()
                    .fill(running ? Color.green : Color.gray.opacity(0.35))
                    .frame(width: 6, height: 6)
                Text(fav.name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            if let n = quickJumpIndex, n >= 1, n <= 9, !isHovered {
                Text("⌥\(n)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.primary.opacity(0.08))
                    )
            }

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
        .frame(height: 38)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isSelected
                      ? Color.accentColor.opacity(0.15)
                      : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor.opacity(0.4) : Color.clear,
                    lineWidth: 1
                )
        )
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
        managerList
    }

    // MARK: - Switcher horizontal strip (keyboard-driven; favorites-only)
    private static let switcherCardWidth: CGFloat = 96
    private static let switcherCardSpacing: CGFloat = 10

    @ViewBuilder
    private var switcherHorizontalStrip: some View {
        let favs = filteredFavorites
        ScrollViewReader { scrollProxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Self.switcherCardSpacing) {
                    ForEach(Array(favs.enumerated()), id: \.element.id) { idx, fav in
                        SwitcherAppCard(
                            fav: fav,
                            favVM: favVM,
                            isSelected: isSelected(rowIndex(for: "fav:\(fav.id)")),
                            quickJumpIndex: idx < 9 ? idx + 1 : nil,
                            onActivate: {
                                favVM.launchApp(fav)
                                onAppLaunched()
                            }
                        )
                        .id(fav.id)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .overlay(alignment: .leading) {
                LinearGradient(
                    colors: [Color(nsColor: .windowBackgroundColor).opacity(0.85), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 20)
                .allowsHitTesting(false)
            }
            .overlay(alignment: .trailing) {
                LinearGradient(
                    colors: [.clear, Color(nsColor: .windowBackgroundColor).opacity(0.85)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 20)
                .allowsHitTesting(false)
            }
            .onChange(of: selectedIndex) { newIndex in
                let favs = filteredFavorites
                guard newIndex >= 0, newIndex < favs.count else { return }
                withAnimation(.easeOut(duration: 0.15)) {
                    scrollProxy.scrollTo(favs[newIndex].id, anchor: .center)
                }
            }
        }
    }

    /// Switcher mode empty state — shown when the user hasn't added any favorites.
    private var switcherEmptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "star")
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
            Text("No favorites yet")
                .font(.system(size: 12, weight: .medium))
            Text("Add favorites from Settings → Favorite Apps.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: - Manager list (existing favorites/pinned/recent/running ordering)
    @ViewBuilder
    private var managerList: some View {
        let pinned = store.filteredApps.filter { store.pinnedBundleIDs.contains($0.bundleIdentifier) }
        let other = store.filteredApps.filter {
            !store.pinnedBundleIDs.contains($0.bundleIdentifier)
        }

        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                if !favVM.favorites.isEmpty {
                    SectionHeader(title: "FAVORITES", icon: "star.fill", count: favVM.favorites.count)
                        .padding(.top, 4)
                    ForEach(Array(favVM.favorites.enumerated()), id: \.element.id) { index, fav in
                        PopoverFavoriteRow(fav: fav, favVM: favVM, onLaunched: onAppLaunched,
                                           isSelected: isSelected(rowIndex(for: "fav:\(fav.id)")),
                                           quickJumpIndex: index < 9 ? index + 1 : nil)
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
                        .padding(.top, 6)
                    ForEach(pinned, id: \.id) { app in
                        AppRowView(
                            app: app,
                            isSelected: isSelected(rowIndex(for: "pin:\(app.bundleIdentifier)")),
                            onPin: nil,
                            onUnpin: { store.unpinApp(app.bundleIdentifier) },
                            onQuit: { store.quitApp(app.bundleIdentifier) },
                            onHide: { store.excludeApp(app.bundleIdentifier) },
                            onDetails: nil
                        )
                        .onTapGesture { store.activateApp(app.bundleIdentifier); onAppLaunched() }
                    }
                }

                if !other.isEmpty {
                    SectionHeader(title: "RUNNING", icon: "app.dashed", count: nil)
                        .padding(.top, 6)
                    ForEach(other, id: \.id) { app in
                        AppRowView(
                            app: app,
                            isSelected: isSelected(rowIndex(for: "other:\(app.bundleIdentifier)")),
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
            .padding(.bottom, 4)
        }
    }

    // MARK: - Footer
    @ViewBuilder
    private var footerBar: some View {
        if isSwitcher {
            switcherHintBar
        } else {
            managerFooter
        }
    }

    /// Compact key-hint bar shown only in switcher mode.
    private var switcherHintBar: some View {
        HStack(spacing: 12) {
            keyHint("⏎",   label: "Switch")
            keyHint("← →", label: "Navigate")
            keyHint("⌥1–9", label: "Jump")
            keyHint("esc", label: "Close")
            Spacer()
            Text("\(selectableRows.count) result\(selectableRows.count == 1 ? "" : "s")")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    private func keyHint(_ key: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                )
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    /// Original manager-mode footer: count, quick actions, refresh, settings.
    private var managerFooter: some View {
        HStack(spacing: 8) {
            Text("\(store.filteredApps.count) app\(store.filteredApps.count == 1 ? "" : "s")")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            if memoryTotal > 0 {
                HStack(spacing: 4) {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(Color.primary.opacity(0.12))
                            .frame(width: 36, height: 5)
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(memoryColor)
                            .frame(width: max(2, 36 * memoryRatio), height: 5)
                    }
                    Text(memoryLabel)
                        .font(.system(size: 10))
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
            Button(action: { store.refreshRunningApps(); fetchMemoryStats() }) {
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

    private var memoryRatio: CGFloat {
        guard memoryTotal > 0 else { return 0 }
        return min(1, CGFloat(memoryUsed) / CGFloat(memoryTotal))
    }

    private var memoryColor: Color {
        if memoryRatio > 0.8 { return .orange }
        if memoryRatio > 0.65 { return .yellow.opacity(0.8) }
        return Color.green.opacity(0.7)
    }

    private var memoryLabel: String {
        let usedGB = Double(memoryUsed) / 1_073_741_824
        let totalGB = Double(memoryTotal) / 1_073_741_824
        return String(format: "%.1f/%.0f GB", usedGB, totalGB)
    }

    private func fetchMemoryStats() {
        let total = ProcessInfo.processInfo.physicalMemory
        let pageSize = UInt64(sysconf(Int32(_SC_PAGESIZE)))

        var info = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            memoryTotal = total
            memoryUsed = 0
            return
        }

        let usedPages = UInt64(info.active_count)
            + UInt64(info.wire_count)
            + UInt64(info.compressor_page_count)
        memoryTotal = total
        memoryUsed = min(total, usedPages * pageSize)
    }

    // MARK: - Helpers
    private func isSelected(_ index: Int) -> Bool { index >= 0 && selectedIndex == index }

    /// Position of the row with the given selectable id in the current visible list.
    /// Returns -1 if not present (so the row never shows as selected).
    private func rowIndex(for id: String) -> Int {
        selectableRows.firstIndex(where: { $0.id == id }) ?? -1
    }

    private func moveSelection(by delta: Int) {
        let rows = selectableRows
        let maxIndex = rows.count - 1
        guard maxIndex >= 0 else { return }
        selectedIndex = max(0, min(maxIndex, selectedIndex + delta))
    }

    private func activateSelected() {
        let rows = selectableRows
        guard selectedIndex >= 0, selectedIndex < rows.count else { return }
        rows[selectedIndex].action()
    }

    /// Cmd+1..9 quick-jump: directly invoke the Nth visible row (1-indexed).
    private func activateRow(at index: Int) {
        let rows = selectableRows
        guard index >= 0, index < rows.count else { return }
        rows[index].action()
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
    var onCmdDigit: ((Int) -> Void)? = nil

    func makeNSView(context: Context) -> NSView {
        let view = KeyCaptureNSView()
        view.onKeyEvent = { event in
            // Cmd+1..9 quick-jump (only if the cmd-digit handler was provided)
            if let cmdDigit = onCmdDigit,
               event.modifierFlags.contains(.command),
               let chars = event.charactersIgnoringModifiers,
               let digit = Int(chars), digit >= 1 && digit <= 9 {
                cmdDigit(digit)
                return
            }
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

// MARK: - Switcher App Card (horizontal launcher strip)
/// Icon-forward card used in the keyboard-shortcut switcher overlay.
/// Larger icon (48 px), subtle running indicator, and clear focus state
/// make it easy to scan and select with arrow keys.
struct SwitcherAppCard: View {
    let fav: FavoriteApp
    @ObservedObject var favVM: FavoriteAppsViewModel
    var isSelected: Bool = false
    var quickJumpIndex: Int? = nil
    var onActivate: () -> Void

    @State private var isHovered = false

    private var running: Bool { favVM.isRunning(fav) }

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let icon = NSWorkspace.shared.icon(forFile: fav.path) as NSImage? {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Image(systemName: "star.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 48, height: 48)
                .shadow(color: .black.opacity(0.12), radius: 2, y: 1)

                if let n = quickJumpIndex, n >= 1, n <= 9 {
                    Text("\(n)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.7))
                        .frame(width: 14, height: 14)
                        .background(
                            Circle().fill(Color.primary.opacity(0.12))
                        )
                        .overlay(
                            Circle().strokeBorder(Color.primary.opacity(0.18), lineWidth: 0.5)
                        )
                        .offset(x: 6, y: -4)
                }

                if running {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                        .overlay(
                            Circle().strokeBorder(.background, lineWidth: 1.5)
                        )
                        .offset(x: 4, y: 4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
            }

            Text(fav.name)
                .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 28, alignment: .top)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(width: 96, height: 104)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    isSelected
                        ? Color.accentColor.opacity(0.15)
                        : (isHovered ? Color.primary.opacity(0.06) : Color.clear)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor.opacity(0.5) : Color.clear,
                    lineWidth: 1.5
                )
        )
        .scaleEffect(isSelected ? 1.04 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isSelected)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onTapGesture { onActivate() }
        .onHover { isHovered = $0 }
        .help(running ? "\(fav.name) — Running" : fav.name)
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    let icon: String
    var count: Int?
    var subtitle: String?

    var body: some View {
        HStack(spacing: 5) {
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
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
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
