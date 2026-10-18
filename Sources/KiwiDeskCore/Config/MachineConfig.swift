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

/// A file of `GuiConfig` leaves kept in `MachineLocation`'s folder
/// (#2324): `machine.json`, which never travels, and
/// `bindings.json`, which travels as the bundle's own field.
protocol MachineFile: Codable, Sendable {
    static var fileName: String { get }
    static var currentFormat: Int { get }
    /// Which `MachineConfig.moves` entries land in this file.
    static var destination: MachineConfig.Destination { get }
    init()
    init(of config: GuiConfig)
    func applied(to config: GuiConfig) -> GuiConfig
}

extension MachineConfig: MachineFile {
    static let fileName = "machine.json"
    static let destination = Destination.machine
}

/// Reads and writes one `MachineFile`.
struct MachineFileStore<File: MachineFile> {
    let url: URL

    init(directory: URL) {
        url = directory.appendingPathComponent(File.fileName)
    }

    /// The stored leaves; empty where the file is absent or does
    /// not decode, which is a Mac that remembers nothing yet.
    func load() -> File {
        guard let data = try? Data(contentsOf: url),
            let file = try? JSONDecoder().decode(File.self, from: data)
        else { return File() }
        return file
    }

    /// Writes the leaves; refuses a file a newer build wrote
    /// (#2325).
    func save(_ file: File) throws {
        try refuseNewer()
        keepCorrupt()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(file).write(to: url, options: .atomic)
    }

    /// Takes this file's leaves out of a `gui.json` written before
    /// they moved (`legacy`, its raw bytes) — the one crossing, run
    /// ahead of the migration that strips them there, over every
    /// `MachineConfig.moves` entry for this file the bytes are
    /// below. A leaf this Mac already holds outranks the shared
    /// copy; otherwise the first Mac to migrate a shared file takes
    /// every entry (#2324 ruling 10). Returns the leaves still owed
    /// where the write failed, for the caller to compose in memory
    /// without rewriting the file; nil once nothing is owed.
    func carry(fromLegacy legacy: Data) -> File? {
        guard
            let format =
                (try? JSONSerialization.jsonObject(with: legacy)
                as? [String: Any]).map({ $0["format"] as? Int ?? 0 }),
            let root = try? JSONSerialization.jsonObject(
                with: ConfigMigration.migratedKeepingMachineLeaves(legacy)
                    ?? legacy
            ) as? [String: Any]
        else { return nil }
        var owed: [String: Any] = [:]
        for move in MachineConfig.moves
        where move.destination == File.destination
            && format < move.guiFormat
        {
            for key in move.keys { owed[key] = root[key] }
        }
        guard !owed.isEmpty else { return nil }
        var stored =
            (try? Data(contentsOf: url)).flatMap {
                try? JSONSerialization.jsonObject(with: $0)
                    as? [String: Any]
            } ?? [:]
        for (key, value) in owed where Self.isEmpty(stored[key]) {
            stored[key] = value
        }
        // Owed leaves that will not decode move as they stand: the
        // new home keeps the bytes and refuses to overwrite them
        // (`keepsUnreadable`), so the strip loses nothing.
        guard let carried = Self.decoded(owed) else {
            return writeRaw(stored) ? nil : File()
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

    /// `root` written as it stands, stamped with this file's
    /// format; false where it cannot land or a newer build owns
    /// the file.
    private func writeRaw(_ root: [String: Any]) -> Bool {
        guard NewerFormatOnDisk.check(url, knows: File.currentFormat) == nil
        else { return false }
        var root = root
        root["format"] = File.currentFormat
        guard
            let bytes = try? JSONSerialization.data(
                withJSONObject: root,
                options: [.prettyPrinted, .sortedKeys]
            )
        else { return false }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try bytes.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    private static func decoded(_ root: [String: Any]) -> File? {
        guard !root.isEmpty,
            let bytes = try? JSONSerialization.data(withJSONObject: root)
        else { return nil }
        return try? JSONDecoder().decode(File.self, from: bytes)
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

typealias MachineConfigStore = MachineFileStore<MachineConfig>
typealias DesktopBindingsStore = MachineFileStore<DesktopBindingsFile>

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
        /// The machine-folder file the leaves move into.
        let destination: Destination
        /// The bundle's top-level field a backup carries them in,
        /// lifted out of its `config`; nil drops them there.
        let bundleField: String?
    }

    /// The two files of `MachineLocation`'s folder that hold
    /// `GuiConfig` leaves.
    enum Destination: Sendable { case machine, bindings }

    static let moves = [
        Move(
            guiFormat: 9,
            bundleFormat: 28,
            keys: ["desktop_spaces"],
            destination: .machine,
            bundleField: nil
        ),
        Move(
            guiFormat: 10,
            bundleFormat: 29,
            keys: ["profile_bindings"],
            destination: .bindings,
            bundleField: "profileBindings"
        ),
    ]
}
