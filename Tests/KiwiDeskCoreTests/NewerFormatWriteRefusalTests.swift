import Foundation
import Testing

@testable import KiwiDeskCore

/// A file a newer KiwiDesk wrote is never overwritten by this
/// build (#2325): its decoder refuses the file, so a write would
/// replace a setup it could not read — on a synced config folder,
/// another Mac's. Fixtures are built by the encoder and re-stamped,
/// so the newer file differs from a current one by its format only.
@Suite("Newer-format write refusal", .serialized)
@MainActor
struct NewerFormatWriteRefusalTests {
    private func scratch() throws -> URL {
        let dir =
            testTemporaryDirectory
            .appendingPathComponent(
                "kiwi-newer-format-\(UUID().uuidString)"
            )
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        return dir
    }

    /// `file` re-stamped from `format` to `format + 1`.
    private func stampNewer(_ file: URL, from format: Int) throws {
        let text = String(
            decoding: try Data(contentsOf: file),
            as: UTF8.self
        )
        let current = "\"format\" : \(format),"
        #expect(text.contains(current))
        try text.replacingOccurrences(
            of: current,
            with: "\"format\" : \(format + 1),"
        ).write(to: file, atomically: true, encoding: .utf8)
    }

    private func profile(_ name: String) -> Profile {
        Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: ["A"])],
            spaceModes: ["1": .bsp],
            settings: TilingSettings(),
            savedAt: Date(timeIntervalSince1970: 1_780_000_000)
        )
    }

    @Test("The core's gui.json store keeps a newer file")
    func guiStoreKeepsNewer() throws {
        let dir = try scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        let core = makeTestCore(configDirectory: dir)
        var config = GuiConfig()
        config.spaces = [SpaceID("code")]
        try core.guiConfigStore.save(config)
        let file = core.guiConfigStore.url
        try stampNewer(file, from: GuiConfig.currentFormat)
        let before = try Data(contentsOf: file)
        #expect(core.guiConfigStore.load() == nil)
        #expect(throws: NewerFormatOnDisk.self) {
            try core.guiConfigStore.save(GuiConfig())
        }
        #expect(try Data(contentsOf: file) == before)
    }

    @Test("A current, older or missing gui.json is written")
    func guiStoreWritesOtherwise() throws {
        let dir = try scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = GuiConfigStore(
            directory: dir,
            machine: dir.appendingPathComponent("machine")
        )
        try store.save(GuiConfig())
        try store.save(GuiConfig())
        let file = dir.appendingPathComponent("gui.json")
        let older = String(
            decoding: try Data(contentsOf: file),
            as: UTF8.self
        ).replacingOccurrences(
            of: "\"format\" : \(GuiConfig.currentFormat),",
            with: "\"format\" : 1,"
        )
        try older.write(to: file, atomically: true, encoding: .utf8)
        var config = GuiConfig()
        config.spaces = [SpaceID("kept")]
        try store.save(config)
        #expect(store.load()?.spaces == [SpaceID("kept")])
    }

    @Test("A profile write keeps a newer file of that name")
    func profileWriteKeepsNewer() throws {
        let dir = try scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        let core = makeTestCore(configDirectory: dir)
        try core.profiles.write(profile("Desk"))
        let file = try core.profiles.fileURL(name: "Desk")
        try stampNewer(file, from: Profile.currentFormat)
        let before = try Data(contentsOf: file)
        #expect(throws: NewerFormatOnDisk.self) {
            try core.profiles.write(profile("Desk"))
        }
        #expect(throws: NewerFormatOnDisk.self) {
            try core.profiles.save(profile("Desk"))
        }
        #expect(try Data(contentsOf: file) == before)
    }

    @Test("A current profile file is rewritten")
    func profileWriteOverCurrent() throws {
        let dir = try scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        let core = makeTestCore(configDirectory: dir)
        try core.profiles.write(profile("Desk"))
        var next = profile("Desk")
        next.spaceModes = ["1": .stack]
        try core.profiles.write(next)
        #expect(
            try core.profiles.read(name: "Desk").spaceModes
                == ["1": .stack]
        )
    }

    @Test("A file whose format cannot be read is not refused")
    func unreadableFormatIsNotNewer() throws {
        let dir = try scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("gui.json")
        try Data("not json".utf8).write(to: file)
        #expect(NewerFormatOnDisk.check(file, .guiConfig, knows: 1) == nil)
        try Data(#"{"format": "7"}"#.utf8).write(to: file)
        #expect(NewerFormatOnDisk.check(file, .guiConfig, knows: 1) == nil)
        try Data(#"{"format": 2}"#.utf8).write(to: file)
        #expect(
            NewerFormatOnDisk.check(file, .guiConfig, knows: 1)
                == NewerFormatOnDisk(artifact: .guiConfig, format: 2)
        )
    }
}
