import Foundation
import Testing

@testable import KiwiDeskCore

/// `gui.json`'s machine-local leaves live in `machine.json`
/// (#2324): a `gui.json` other Macs share never carries them, the
/// store composes them back in, and a file written before the
/// move hands its copy across once.
@Suite("Machine-local GuiConfig leaves (#2324)")
struct MachineConfigTests {
    private let stamp = DesktopIdentity(raw: "STAMP-M")

    private func scratch() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("kiwi-machine-\(UUID().uuidString)")
    }

    private func store(_ dir: URL) -> GuiConfigStore {
        GuiConfigStore(
            directory: dir,
            machine: dir.appendingPathComponent("machine")
        )
    }

    private func root(_ url: URL) throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: url))
                as? [String: Any]
        )
    }

    private var remembering: GuiConfig {
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        config.desktopSpaces = [.identity(stamp): SpaceID("1")]
        config.profileBindings = [
            .number(2): DesktopBinding(profile: "Work", desktop: 2)
        ]
        return config
    }

    /// The register and the file agree: every machine-local field
    /// is a `MachineConfig` field and the other way round.
    @Test("machineLocalFields is MachineConfig's field list")
    func registerMatchesTheFile() {
        let fields = Set(fieldNames(MachineConfig()))
            .union(fieldNames(DesktopBindingsFile()))
            .subtracting(["format"])
        #expect(fields == GuiConfig.machineLocalFields)
        let gui = Set(fieldNames(GuiConfig()))
        #expect(GuiConfig.machineLocalFields.isSubset(of: gui))
    }

    @Test("gui.json never carries a machine-local key")
    func guiEncodingSkipsTheLeaves() throws {
        let text = String(
            decoding: try JSONEncoder().encode(remembering),
            as: UTF8.self
        )
        let keys =
            MachineConfig.CodingKeys.allCases.map(\.rawValue)
            + DesktopBindingsFile.CodingKeys.allCases.map(\.rawValue)
        for key in keys where key != "format" {
            #expect(!text.contains("\"\(key)\""), "\(key) in gui.json")
        }
    }

    @Test("A save splits the leaves out and a load composes them")
    func storeSplitsAndComposes() throws {
        let dir = scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = store(dir)
        try store.saveIncludingBindings(remembering)
        #expect(try root(store.url)["desktop_spaces"] == nil)
        #expect(try root(store.machine.url)["desktop_spaces"] != nil)
        #expect(store.load()?.desktopSpaces == remembering.desktopSpaces)
        #expect(try root(store.url)["profile_bindings"] == nil)
        #expect(try root(store.bindingsFile.url)["profile_bindings"] != nil)
        #expect(
            store.load()?.profileBindings == remembering.profileBindings
        )
    }

    /// Writes `config` as a `gui.json` from before the move: its
    /// format the one below, its Desktop memory inline.
    private func writeLegacy(_ config: GuiConfig, to store: GuiConfigStore)
        throws
    {
        var gui = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(config)
            ) as? [String: Any]
        )
        let machine = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(MachineConfig(of: config))
            ) as? [String: Any]
        )
        gui["format"] = MachineConfig.moves[0].guiFormat - 1
        gui["desktop_spaces"] = machine["desktop_spaces"]
        try FileManager.default.createDirectory(
            at: store.url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONSerialization.data(withJSONObject: gui)
            .write(to: store.url)
    }

    @Test("A legacy gui.json hands its memory to machine.json once")
    func legacyMemoryIsCarried() throws {
        let dir = scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = store(dir)
        try writeLegacy(remembering, to: store)
        let loaded = try #require(store.load())
        #expect(loaded.desktopSpaces == remembering.desktopSpaces)
        let gui = try root(store.url)
        #expect(gui["desktop_spaces"] == nil)
        #expect(gui["format"] as? Int == GuiConfig.currentFormat)
        #expect(
            store.machine.load().desktopSpaces
                == remembering.desktopSpaces
        )
    }

    /// The first Mac to migrate a shared file takes its memory; a
    /// Mac that already remembers keeps its own.
    @Test("A Mac's own memory outranks a legacy copy")
    func ownMemoryWins() throws {
        let dir = scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = store(dir)
        var own = MachineConfig()
        own.desktopSpaces = [.identity(stamp): SpaceID("9")]
        try store.machine.save(own, backups: nil)
        try writeLegacy(remembering, to: store)
        #expect(store.load()?.desktopSpaces == own.desktopSpaces)
    }

    /// A carry that cannot land must not let the migration strip
    /// the only copy.
    @Test("A failed carry leaves gui.json unrewritten")
    func failedCarryKeepsTheCopy() throws {
        let dir = scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = store(dir)
        try writeLegacy(remembering, to: store)
        try FileManager.default.createDirectory(
            at: store.machine.url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        // A newer build's machine.json refuses the write.
        try Data(#"{"format":999}"#.utf8).write(to: store.machine.url)
        let loaded = try #require(store.load())
        // Composed in memory, so the session still has it.
        #expect(loaded.desktopSpaces == remembering.desktopSpaces)
        #expect(try root(store.url)["desktop_spaces"] != nil)
        // A save refuses before the shared file is rewritten.
        #expect(throws: NewerFormatOnDisk.self) {
            try store.save(loaded)
        }
        #expect(try root(store.url)["desktop_spaces"] != nil)
    }

    /// A machine folder that reads but cannot be written: this
    /// Mac's own memory still outranks the legacy copy for the
    /// session, and a save writes nothing shared before the
    /// machine file fails (#2324).
    @Test("An unwritable machine folder keeps both copies")
    func unwritableMachineFolderKeepsBoth() throws {
        let dir = scratch()
        let files = FileManager.default
        defer { try? files.removeItem(at: dir) }
        let store = store(dir)
        var own = MachineConfig()
        own.desktopSpaces = [.identity(stamp): SpaceID("9")]
        try store.machine.save(own, backups: nil)
        try writeLegacy(remembering, to: store)
        let folder = store.machine.url.deletingLastPathComponent()
        try files.setAttributes(
            [.posixPermissions: 0o555],
            ofItemAtPath: folder.path
        )
        defer {
            try? files.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: folder.path
            )
        }
        let loaded = try #require(store.load())
        #expect(loaded.desktopSpaces == own.desktopSpaces)
        #expect(try root(store.url)["desktop_spaces"] != nil)
        #expect(throws: (any Error).self) { try store.save(loaded) }
        #expect(try root(store.url)["desktop_spaces"] != nil)
    }

    /// The strip is a textual edit: only the moved entry and its
    /// comma leave, and every other byte — a Double above all,
    /// which re-serializing re-encodes — stays as written.
    @Test("The strip removes the entry and nothing else")
    func stripIsSurgical() throws {
        var config = remembering
        config.scrollGesture.stepDistance = 0.4
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let current = String(
            decoding: try encoder.encode(config),
            as: UTF8.self
        )
        let old = MachineConfig.moves[0].guiFormat - 1
        let stamp = "\"format\" : \(GuiConfig.currentFormat),"
        let base = current.replacingOccurrences(
            of: stamp,
            with: "\"format\" : \(old),"
        )
        let anchor = "  \"float_automatically\""
        let entry = "  \"desktop_spaces\" : {\n    \"k\" : \"1\"\n  },\n"
        #expect(base.contains(anchor) && base != current)
        let legacy = base.replacingOccurrences(
            of: anchor,
            with: entry + anchor
        )
        let migrated = try #require(
            ConfigMigration.migrated(Data(legacy.utf8))
        )
        #expect(String(decoding: migrated, as: UTF8.self) == current)
    }

    /// Another Mac's memory never travels: an old backup's copy is
    /// dropped, its profiles left as they were.
    @Test("An old bundle's Desktop memory is dropped")
    func bundleDropsTheMemory() throws {
        let bundle: [String: Any] = [
            "format": MachineConfig.moves[0].bundleFormat - 1,
            "writtenBy": "test",
            "config": [
                "spaces": ["1"],
                "desktop_spaces": ["k": "1"],
            ],
            "profiles": [],
            "palettes": [],
        ]
        let data = try JSONSerialization.data(withJSONObject: bundle)
        let migrated = try #require(ConfigMigration.migrated(data))
        let out = try #require(
            JSONSerialization.jsonObject(with: migrated)
                as? [String: Any]
        )
        let config = try #require(out["config"] as? [String: Any])
        #expect(config["desktop_spaces"] == nil)
        #expect(config["spaces"] as? [String] == ["1"])
    }
}
