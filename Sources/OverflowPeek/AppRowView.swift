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
    var hideActionsOnSelection: Bool = false
    @State private var isHovered = false

    private var isPinned: Bool { app.confidence == .pinned }

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if let icon = app.item.icon {
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

            Text(app.name)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            if isPinned {
                Circle()
                    .fill(Color.accentColor.opacity(0.5))
                    .frame(width: 5, height: 5)
            }

            trailingButton
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(height: 38)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor.opacity(0.4) : Color.clear,
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private var trailingButton: some View {
        let shouldShow = hideActionsOnSelection ? isHovered : (isHovered || isSelected)
        if shouldShow {
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
}
