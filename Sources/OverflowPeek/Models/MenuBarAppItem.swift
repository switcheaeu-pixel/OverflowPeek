import AppKit

/// Data model for a discovered menu bar app.
struct MenuBarAppItem: Identifiable, Equatable, Codable {
    let id: String  // Bundle ID as unique identifier
    let bundleIdentifier: String
    let name: String
    let executablePath: String
    let pid: Int32
    let activationPolicy: String

    var icon: NSImage? {
        guard let url = URL(string: "file://\(executablePath)") else { return nil }
        return NSWorkspace.shared.icon(forFile: executablePath)
    }

    enum CodingKeys: String, CodingKey {
        case bundleIdentifier
        case name
        case executablePath
        case pid
        case activationPolicy
    }

    init(
        bundleIdentifier: String,
        name: String,
        executablePath: String,
        pid: Int32,
        activationPolicy: String
    ) {
        self.id = bundleIdentifier
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.executablePath = executablePath
        self.pid = pid
        self.activationPolicy = activationPolicy
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.bundleIdentifier = try container.decode(String.self, forKey: .bundleIdentifier)
        self.id = bundleIdentifier
        self.name = try container.decode(String.self, forKey: .name)
        self.executablePath = try container.decode(String.self, forKey: .executablePath)
        self.pid = try container.decode(Int32.self, forKey: .pid)
        self.activationPolicy = try container.decode(String.self, forKey: .activationPolicy)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bundleIdentifier, forKey: .bundleIdentifier)
        try container.encode(name, forKey: .name)
        try container.encode(executablePath, forKey: .executablePath)
        try container.encode(pid, forKey: .pid)
        try container.encode(activationPolicy, forKey: .activationPolicy)
    }
}
