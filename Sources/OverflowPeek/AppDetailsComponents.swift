import SwiftUI
import AppKit

// MARK: - Resource Monitor
@MainActor
class AppResourceMonitor: ObservableObject {
    @Published var cpuUsage: Double = 0.0
    @Published var memoryUsage: Double = 0.0

    private var monitorTask: Task<Void, Never>?
    private let pid: pid_t

    init(pid: pid_t) {
        self.pid = pid
        startMonitoring()
    }

    deinit {
        monitorTask?.cancel()
    }

    private func startMonitoring() {
        monitorTask = Task { @MainActor in
            while !Task.isCancelled {
                updateResourceUsage()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func updateResourceUsage() {
        guard pid > 0 else { return }

        var info = proc_taskinfo()
        let size = MemoryLayout<proc_taskinfo>.size
        let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, Int32(size))

        guard result == size else { return }
        memoryUsage = Double(info.pti_resident_size) / 1024.0 / 1024.0
        cpuUsage = Double(info.pti_total_user + info.pti_total_system) / 1_000_000_000.0
    }
}

// MARK: - Supporting Views

struct SectionTitle: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(Color.gray)
            .textCase(.uppercase)
            .tracking(0.8)
            .padding(.leading, 4)
    }
}

struct DetailRowModern: View {
    let label: String
    let value: String
    var copyable: Bool = false
    @State private var showCopied = false
    @State private var isHovered = false

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.gray)

            Spacer()

            HStack(spacing: 8) {
                Text(value)
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.8))
                    .lineLimit(1)
                    .truncationMode(.middle)

                if copyable {
                    Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 14))
                        .foregroundColor(showCopied ? .green : .gray)
                        .opacity(isHovered || showCopied ? 1 : 0)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .background(isHovered ? Color.white.opacity(0.05) : Color.clear)
        .onHover { isHovered = $0 }
        .onTapGesture {
            if copyable {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
                showCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showCopied = false
                }
            }
        }
    }
}

struct ResourceCardModern: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(color)
            }

            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(white: 0.9))
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            ZStack {
                Color.black.opacity(0.2)
                if isHovered {
                    color.opacity(0.1)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .onHover { isHovered = $0 }
    }
}

struct ActionButtonModern: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    var isDestructive: Bool = false
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(color.opacity(0.2))
                        .frame(width: 32, height: 32)

                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isDestructive && isHovered ? .red : Color(white: 0.8))
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(isDestructive && isHovered ? Color.red.opacity(0.7) : .gray)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(isDestructive && isHovered ? .red : Color.gray.opacity(0.6))
            }
            .padding(10)
            .background(
                ZStack {
                    Color.black.opacity(0.2)
                    if isHovered {
                        if isDestructive {
                            Color.red.opacity(0.1)
                        } else {
                            Color.white.opacity(0.1)
                        }
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isDestructive && isHovered ?
                        Color.red.opacity(0.3) :
                        Color.white.opacity(0.05),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
