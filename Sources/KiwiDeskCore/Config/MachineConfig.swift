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
    /// there. On a `gui.json` other Macs share, the first Mac to
    /// migrate takes every entry (#2324 ruling 10). Returns whether
    /// the bytes may be migrated: false only where leaves were
    /// owed and the write failed, so the next read carries again.
    func carry(fromLegacy legacy: Data) -> Bool {
        guard
            let root = try? JSONSerialization.jsonObject(with: legacy)
                as? [String: Any],
            (root["format"] as? Int ?? 0) < MachineConfig.movedAtFormat
        else { return true }
        let key = MachineConfig.CodingKeys.desktopSpaces.rawValue
        guard let value = root[key],
            let bytes = try? JSONSerialization.data(
                withJSONObject: [key: value]
            ),
            let carried = try? JSONDecoder().decode(
                MachineConfig.self,
                from: bytes
            )
        else { return true }
        var stored = load()
        guard stored.desktopSpaces.isEmpty else { return true }
        stored.desktopSpaces = carried.desktopSpaces
        do {
            try save(stored)
            return true
        } catch {
            return false
        }
    }
}

extension MachineConfig {
    /// The `GuiConfig.currentFormat` that moved the leaves out of
    /// `gui.json`, spelled as history: the strip step and the
    /// carry stand down at it.
    static let movedAtFormat = 9
}
