import Foundation

/// The `GuiConfig` leaves that mean something on this Mac alone
/// (#2324), stored as `machine.json` in `MachineLocation`'s folder
/// rather than in `gui.json`, which a user may sync to another
/// Mac. `GuiConfig.machineLocalFields` names them; the in-memory
/// `GuiConfig` keeps carrying them, and `GuiConfigStore` splits
/// and composes the two files in one place.
public struct MachineConfig: Codable, Equatable, Sendable {
    /// 1 = `desktop_spaces` (#2324).
    public static let currentFormat = 1

    public var format = MachineConfig.currentFormat
    /// `GuiConfig.desktopSpaces`.
    public var desktopSpaces: [DesktopKey: SpaceID] = [:]

    public init() {}

    /// The machine-local leaves of `config`.
    public init(of config: GuiConfig) {
        desktopSpaces = config.desktopSpaces
    }

    /// `config` carrying these leaves.
    public func applied(to config: GuiConfig) -> GuiConfig {
        var config = config
        config.desktopSpaces = desktopSpaces
        return config
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case format
        case desktopSpaces = "desktop_spaces"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decoded =
            try container.decodeIfPresent(Int.self, forKey: .format) ?? 0
        guard decoded <= Self.currentFormat else {
            throw DecodingError.dataCorruptedError(
                forKey: .format,
                in: container,
                debugDescription:
                    "machine config format \(decoded) is newer "
                    + "than supported \(Self.currentFormat)"
            )
        }
        desktopSpaces =
            try container.decodeIfPresent(
                [DesktopKey: SpaceID].self,
                forKey: .desktopSpaces
            ) ?? [:]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(format, forKey: .format)
        // A `.number` key names no Desktop once persisted
        // (profiles.md ▸ the `.number` fallback, #1230).
        try container.encode(
            desktopSpaces.filter { $0.key.isIdentity },
            forKey: .desktopSpaces
        )
    }
}

/// Reads and writes `machine.json`.
struct MachineConfigStore {
    static let fileName = "machine.json"

    let url: URL

    init(directory: URL) {
        url = directory.appendingPathComponent(Self.fileName)
    }

    /// The stored leaves; empty where the file is absent or does
    /// not decode, which is a Mac that remembers nothing yet.
    func load() -> MachineConfig {
        guard let data = try? Data(contentsOf: url),
            let config = try? JSONDecoder().decode(
                MachineConfig.self,
                from: data
            )
        else { return MachineConfig() }
        return config
    }

    /// Writes the leaves; refuses a file a newer build wrote
    /// (#2325).
    func save(_ config: MachineConfig) throws {
        try NewerFormatOnDisk.refuse(url, MachineConfig.currentFormat)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(config).write(to: url, options: .atomic)
    }

    /// Takes the machine-local leaves out of a `gui.json` written
    /// before they moved (`legacy`, its raw bytes) — the one
    /// crossing, run ahead of the migration that strips them
    /// there, over every `MachineConfig.moves` entry the file is
    /// below. A leaf this Mac already holds outranks the shared
    /// copy; otherwise the first Mac to migrate a shared file
    /// takes every entry (#2324 ruling 10). Returns the leaves
    /// still owed where the write failed, for the caller to
    /// compose in memory without rewriting the file; nil once
    /// nothing is owed.
    func carry(fromLegacy legacy: Data) -> MachineConfig? {
        guard
            let root = try? JSONSerialization.jsonObject(with: legacy)
                as? [String: Any]
        else { return nil }
        let format = root["format"] as? Int ?? 0
        var owed: [String: Any] = [:]
        for move in MachineConfig.moves where format < move.guiFormat {
            for key in move.keys { owed[key] = root[key] }
        }
        guard let carried = Self.decoded(owed) else { return nil }
        var stored =
            (try? Data(contentsOf: url)).flatMap {
                try? JSONSerialization.jsonObject(with: $0)
                    as? [String: Any]
            } ?? [:]
        for (key, value) in owed where Self.isEmpty(stored[key]) {
            stored[key] = value
        }
        // A stored file this build cannot read leaves the legacy
        // copy owed; one it can read keeps its own leaves even
        // where the write fails.
        guard let merged = Self.decoded(stored) else { return carried }
        do {
            try save(merged)
            return nil
        } catch {
            return merged
        }
    }

    private static func decoded(_ root: [String: Any]) -> MachineConfig? {
        guard !root.isEmpty,
            let bytes = try? JSONSerialization.data(withJSONObject: root)
        else { return nil }
        return try? JSONDecoder().decode(MachineConfig.self, from: bytes)
    }

    private static func isEmpty(_ value: Any?) -> Bool {
        switch value {
        case nil: true
        case let map as [String: Any]: map.isEmpty
        case let list as [Any]: list.isEmpty
        default: false
        }
    }
}

extension MachineConfig {
    /// One move of leaves out of `gui.json`: the `GuiConfig` and
    /// `SetupBundle` formats whose step strips them, and their
    /// keys there, spelled as history. Append-only: the carry and
    /// `migratingMachineLeavesOut` both read this one table, so a
    /// leaf the strip removes is a leaf the carry took first.
    struct Move: Sendable {
        let guiFormat: Int
        let bundleFormat: Int
        let keys: [String]
    }

    static let moves = [
        Move(guiFormat: 9, bundleFormat: 28, keys: ["desktop_spaces"])
    ]
}
