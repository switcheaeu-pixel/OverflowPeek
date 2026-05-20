import SwiftUI

// MARK: - App Row View
struct AppRowView: View {
    let app: AppDetectionResult
    let isSelected: Bool
    let onPin: (() -> Void)?
    let onUnpin: (() -> Void)?
    let onQuit: (() -> Void)?
    let onHide: (() -> Void)?
    let onDetails: (() -> Void)?
    @State private var isHovered = false

    private var isPinned: Bool { app.confidence == .pinned }

    var body: some View {
        HStack(spacing: 8) {
            appIcon
            VStack(alignment: .leading, spacing: 1) {
                Text(app.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(app.bundleIdentifier)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            trailingButton
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(height: 36)
        .background(selectionBackground)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    private var appIcon: some View {
        Group {
            if let icon = app.item.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .cornerRadius(4)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }
        }
    }

    @ViewBuilder
    private var trailingButton: some View {
        if isHovered || isSelected {
            HStack(spacing: 2) {
                if let onQuit = onQuit {
                    Button(action: onQuit) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Quit this app")
                }
                if isPinned, let action = onUnpin {
                    Button(action: action) {
                        Image(systemName: "pin.slash.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Menu {
                        if let onPin = onPin {
                            Button("Pin to Top") { onPin() }
                        }
                        if let onQuit = onQuit {
                            Button("Quit") { onQuit() }
                        }
                        if let onHide = onHide {
                            Divider()
                            Button("Hide this App") { onHide() }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .frame(width: 24, height: 24)
                }
            }
        }
    }

    private var selectionBackground: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(isSelected ? Color.accentColor.opacity(0.15) : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
    }
}
