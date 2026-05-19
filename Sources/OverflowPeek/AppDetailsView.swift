import SwiftUI
import AppKit

// MARK: - App Details View
struct AppDetailsView: View {
    let item: MenuBarAppItem?
    let bundleIdentifier: String?
    @EnvironmentObject var store: OverflowStore
    @Environment(\.dismiss) var dismiss
    @StateObject private var monitor: AppResourceMonitor
    @State private var showUninstallConfirmation = false
    @State private var showDeepUninstallConfirmation = false
    
    private var windowBackgroundColor: Color {
        return Color(nsColor: .windowBackgroundColor).opacity(0.6)
    }
    
    private var cardBackgroundColor: Color {
        return Color.black.opacity(0.2)
    }
    
    private var hoverBackgroundColor: Color {
        return Color.white.opacity(0.05)
    }
    
    init(item: MenuBarAppItem) {
        self.item = item
        self.bundleIdentifier = nil
        self._monitor = StateObject(wrappedValue: AppResourceMonitor(pid: item.pid))
    }
    
    init(bundleIdentifier: String) {
        self.item = nil
        self.bundleIdentifier = bundleIdentifier
        
        // Try to find running instance
        if let app = NSWorkspace.shared.runningApplications.first(where: { 
            $0.bundleIdentifier == bundleIdentifier && !$0.isTerminated 
        }) {
            self._monitor = StateObject(wrappedValue: AppResourceMonitor(pid: app.processIdentifier))
        } else {
            self._monitor = StateObject(wrappedValue: AppResourceMonitor(pid: -1))
        }
    }
    
    private var appName: String {
        item?.name ?? bundleIdentifier ?? "Unknown"
    }
    
    private var currentBundleID: String {
        item?.bundleIdentifier ?? bundleIdentifier ?? ""
    }
    
    private var appIcon: NSImage? {
        if let item = item {
            return item.icon
        }
        return nil
    }
    
    private var isRunning: Bool {
        let bid = currentBundleID
        return NSWorkspace.shared.runningApplications.contains { 
            $0.bundleIdentifier == bid && !$0.isTerminated 
        }
    }
    
    private var appExecutableURL: URL? {
        if let item = item {
            return URL(fileURLWithPath: item.executablePath)
        }
        return nil
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with blur effect
            HStack {
                Image(systemName: "app.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(appName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 6) {
                        if isRunning {
                            Circle()
                                .fill(.green)
                                .frame(width: 8, height: 8)
                            Text("Running")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        } else {
                            Circle()
                                .fill(.gray)
                                .frame(width: 8, height: 8)
                            Text("Not Running")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            ScrollView {
                VStack(spacing: 24) {
                    // App Info Section
                    VStack(alignment: .leading, spacing: 8) {
                        SectionTitle("APP INFORMATION")
                        
                        VStack(spacing: 0) {
                            DetailRowModern(label: "Bundle ID", value: currentBundleID, copyable: true)
                            Divider().background(Color.white.opacity(0.05)).padding(.leading, 12)
                            
                            if let url = appExecutableURL {
                                DetailRowModern(label: "Location", value: url.path, copyable: true)
                                Divider().background(Color.white.opacity(0.05)).padding(.leading, 12)
                                
                                if let bundle = Bundle(url: url.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()),
                                   let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String {
                                    DetailRowModern(label: "Version", value: version)
                                    Divider().background(Color.white.opacity(0.05)).padding(.leading, 12)
                                }
                            }
                            
                            DetailRowModern(label: "Type", value: "Menu Bar App")
                        }
                        .background(cardBackgroundColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 16)
                    
                    // Resource Usage Section (only if running)
                    if isRunning {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionTitle("RESOURCE USAGE")
                            
                            HStack(spacing: 12) {
                                ResourceCardModern(
                                    icon: "memorychip",
                                    label: "Memory",
                                    value: String(format: "%.1f MB", monitor.memoryUsage),
                                    color: .blue
                                )
                                
                                ResourceCardModern(
                                    icon: "gauge.medium",
                                    label: "Status",
                                    value: "Active",
                                    color: .green
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // Actions Section
                    VStack(alignment: .leading, spacing: 8) {
                        SectionTitle("ACTIONS")
                        
                        VStack(spacing: 8) {
                            ActionButtonModern(
                                icon: "folder.fill",
                                title: "Reveal in Finder",
                                subtitle: "Show application file location",
                                color: .blue
                            ) {
                                revealInFinder()
                            }
                            
                            if isRunning {
                                ActionButtonModern(
                                    icon: "play.fill",
                                    title: "Activate App",
                                    subtitle: "Bring application to front",
                                    color: .green
                                ) {
                                    activateApp()
                                }
                                
                                ActionButtonModern(
                                    icon: "power",
                                    title: "Quit App",
                                    subtitle: "Terminate process gracefully",
                                    color: .red,
                                    isDestructive: true
                                ) {
                                    quitApp()
                                }
                            } else if bundleIdentifier != nil {
                                ActionButtonModern(
                                    icon: "play.fill",
                                    title: "Launch App",
                                    subtitle: "Start the application",
                                    color: .green
                                ) {
                                    launchApp()
                                }
                            }
                            
                            if bundleIdentifier != nil {
                                ActionButtonModern(
                                    icon: "pin.slash.fill",
                                    title: "Unpin App",
                                    subtitle: "Remove from pinned list",
                                    color: .orange
                                ) {
                                    unpinApp()
                                    dismiss()
                                }
                            } else if let item = item {
                                ActionButtonModern(
                                    icon: "pin.fill",
                                    title: "Pin to Top",
                                    subtitle: "Keep window visible always",
                                    color: .orange
                                ) {
                                    pinApp(item)
                                }
                            }
                            
                            // Uninstall options
                            if executableURL != nil {
                                ActionButtonModern(
                                    icon: "trash.fill",
                                    title: "Uninstall App",
                                    subtitle: "Move application to Trash",
                                    color: .red,
                                    isDestructive: true
                                ) {
                                    showUninstallConfirmation = true
                                }
                                
                                ActionButtonModern(
                                    icon: "trash.slash.fill",
                                    title: "Deep Uninstall",
                                    subtitle: "Remove app and all data",
                                    color: .red,
                                    isDestructive: true
                                ) {
                                    showDeepUninstallConfirmation = true
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .padding(.top, 16)
            }
        }
        .frame(width: 400, height: 500)
        .background(
            ZStack {
                Color(red: 0.12, green: 0.12, blue: 0.12).opacity(0.85)
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 10)
        .alert("Uninstall \(appName)?", isPresented: $showUninstallConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Move to Trash", role: .destructive) {
                uninstallApp()
            }
        } message: {
            Text("This will move \(appName) to the Trash. You can restore it from the Trash if needed.")
        }
        .alert("Deep Uninstall \(appName)?", isPresented: $showDeepUninstallConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove Everything", role: .destructive) {
                deepUninstallApp()
            }
        } message: {
            Text("This will permanently remove \(appName) and ALL associated files including:\n\n• Application Support files\n• Preferences and settings\n• Caches and logs\n• Saved application state\n\nThis action cannot be easily undone.")
        }
    }
    
    // MARK: - Actions
    
    private func revealInFinder() {
        guard let url = executableURL else { return }
        
        // Navigate to the .app bundle
        let appBundle = url.deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        NSWorkspace.shared.activateFileViewerSelecting([appBundle])
        dismiss()
    }
    
    private func activateApp() {
        if let item = item {
            store.activateApp(item.bundleIdentifier)
        } else if let bundleID = bundleIdentifier {
            store.activateApp(bundleID)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            dismiss()
        }
    }
    
    private func quitApp() {
        if let item = item {
            if let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == item.pid }) {
                app.terminate()
            }
            dismiss()
        }
    }
    
    private func launchApp() {
        if let bundleID = bundleIdentifier {
            store.activateApp(bundleID)
            dismiss()
        }
    }
    
    private func pinApp(_ item: MenuBarAppItem) {
        store.pinApp(item.bundleIdentifier)
    }
    
    private func unpinApp() {
        if let bundleID = bundleIdentifier {
            store.unpinApp(bundleID)
        }
    }
    
    private var executableURL: URL? {
        if let item = item {
            return URL(fileURLWithPath: item.executablePath)
        }
        return nil
    }
    
    private func uninstallApp() {
        guard let url = executableURL else { return }
        
        // Navigate to the .app bundle
        let appBundle = url.deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        // First quit the app if it's running
        if isRunning {
            if let item = item,
               let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == item.pid }) {
                app.terminate()
            }
            
            // Give the app a moment to quit
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                moveToTrash(appBundle)
            }
        } else {
            moveToTrash(appBundle)
        }
    }
    
    private func moveToTrash(_ url: URL) {
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            
            // If this was a pinned app, unpin it
            if let bundleID = bundleIdentifier {
                store.unpinApp(bundleID)
            }
            
            dismiss()
        } catch {
            // Show error alert
            let alert = NSAlert()
            alert.messageText = "Failed to Uninstall"
            alert.informativeText = "Could not move \(appName) to Trash: \(error.localizedDescription)"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    private func deepUninstallApp() {
        guard let url = executableURL else { return }
        
        // Navigate to the .app bundle
        let appBundle = url.deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        // First quit the app if it's running
        if isRunning {
            if let item = item,
               let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == item.pid }) {
                app.terminate()
            }
            
            // Give the app a moment to quit
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                performDeepUninstall(appBundle: appBundle)
            }
        } else {
            performDeepUninstall(appBundle: appBundle)
        }
    }
    
    private func performDeepUninstall(appBundle: URL) {
        let fileManager = FileManager.default
        var deletedPaths: [String] = []
        var errors: [String] = []
        
        // 1. Move the app bundle to trash
        do {
            try fileManager.trashItem(at: appBundle, resultingItemURL: nil)
            deletedPaths.append(appBundle.path)
        } catch {
            errors.append("App bundle: \(error.localizedDescription)")
        }
        
        // Get the bundle identifier for finding associated files
        let bundleIDToSearch = currentBundleID
        
        // 2. Remove files from various Library locations
        let homeDir = URL(fileURLWithPath: NSHomeDirectory())
        let libraryDir = homeDir.appendingPathComponent("Library")
            
            // Locations to check
            let locationsToCheck: [(String, Bool)] = [
                ("Application Support", true),  // Check subfolders
                ("Preferences", false),          // Check files directly
                ("Caches", true),
                ("Logs", true),
                ("Saved Application State", true),
                ("WebKit", true),
                ("HTTPStorages", true),
                ("Cookies", false)
            ]
            
            for (location, checkSubfolders) in locationsToCheck {
                let locationURL = libraryDir.appendingPathComponent(location)
                
                if checkSubfolders {
                    // Look for folders matching app name or bundle ID
                    removeMatchingItems(in: locationURL, matching: [appName, bundleIDToSearch], fileManager: fileManager, deletedPaths: &deletedPaths, errors: &errors)
                } else {
                    // Look for files matching bundle ID (e.g., .plist files)
                    removeMatchingFiles(in: locationURL, matching: bundleIDToSearch, fileManager: fileManager, deletedPaths: &deletedPaths, errors: &errors)
                }
            }
            
            // 3. Remove container files (for sandboxed apps)
            let containersDir = libraryDir.appendingPathComponent("Containers")
            removeMatchingItems(in: containersDir, matching: [bundleIDToSearch], fileManager: fileManager, deletedPaths: &deletedPaths, errors: &errors)
            
            // 4. Remove group containers
            let groupContainersDir = libraryDir.appendingPathComponent("Group Containers")
            removeMatchingItems(in: groupContainersDir, matching: [bundleIDToSearch], fileManager: fileManager, deletedPaths: &deletedPaths, errors: &errors)
        
        // If this was a pinned app, unpin it
        if let bundleID = bundleIdentifier {
            store.unpinApp(bundleID)
        }
        
        // Show results
        DispatchQueue.main.async {
            let alert = NSAlert()
            
            if errors.isEmpty {
                alert.messageText = "Deep Uninstall Complete"
                alert.informativeText = "Successfully removed \(appName) and \(deletedPaths.count) associated file(s)."
                alert.alertStyle = .informational
            } else {
                alert.messageText = "Deep Uninstall Completed with Errors"
                alert.informativeText = "Removed \(deletedPaths.count) item(s), but encountered \(errors.count) error(s):\n\n" + errors.prefix(3).joined(separator: "\n")
                alert.alertStyle = .warning
            }
            
            alert.addButton(withTitle: "OK")
            alert.runModal()
            
            dismiss()
        }
    }
    
    private func removeMatchingItems(in directory: URL, matching patterns: [String], fileManager: FileManager, deletedPaths: inout [String], errors: inout [String]) {
        guard let items = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return
        }
        
        for item in items {
            let itemName = item.lastPathComponent
            
            // Check if item name contains any of the patterns
            if patterns.contains(where: { pattern in
                itemName.localizedCaseInsensitiveContains(pattern) ||
                itemName.contains(pattern)
            }) {
                do {
                    try fileManager.trashItem(at: item, resultingItemURL: nil)
                    deletedPaths.append(item.path)
                } catch {
                    errors.append("\(item.path): \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func removeMatchingFiles(in directory: URL, matching pattern: String, fileManager: FileManager, deletedPaths: inout [String], errors: inout [String]) {
        guard let items = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return
        }
        
        for item in items {
            // Check if it's a file (not a directory)
            if let isDirectory = try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
               !isDirectory {
                let itemName = item.lastPathComponent
                
                // Check if filename contains the bundle ID
                if itemName.contains(pattern) {
                    do {
                        try fileManager.trashItem(at: item, resultingItemURL: nil)
                        deletedPaths.append(item.path)
                    } catch {
                        errors.append("\(item.path): \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}

