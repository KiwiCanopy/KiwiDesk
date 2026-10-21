import Foundation
import Testing

@testable import KiwiDeskCore

/// One policy for a corrupt config file (#2324 ruling 13): every
/// store's next write overwrites it, after one copy lands in this
/// Mac's `migration-backups/` as `<path>.corrupt`; a readable file
/// leaves no copy.
@Suite("Corrupt file policy (#2324)", .serialized)
@MainActor
struct CorruptFilePolicyTests {
    private let corrupt = Data("{ not json".utf8)

    private func scratch() throws -> URL {
        let dir =
            testTemporaryDirectory
            .appendingPathComponent("kiwi-corrupt-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        return dir
    }

    /// Writes the corrupt bytes over `file`.
    private func spoil(_ file: URL) throws {
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try corrupt.write(to: file)
    }

    private func copy(of file: URL, in core: KiwiCore) -> Data? {
        try? Data(
            contentsOf: MigrationBackup.url(
                of: file,
                suffix: CorruptFile.suffix,
                in: core.migrationBackups
            )
        )
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

    @Test("gui.json and both machine files are kept, then written")
    func sidecarFiles() throws {
        let dir = try scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        let core = makeTestCore(configDirectory: dir)
        let files: [ConfigArtifact] = [
            .guiConfig, .machineConfig, .desktopBindings,
        ]
        for artifact in files { try spoil(core.url(of: artifact)) }
        var config = GuiConfig()
        config.spaces = [SpaceID("kept")]
        try core.guiConfigStore.saveIncludingBindings(config)
        #expect(core.guiConfigStore.load()?.spaces == [SpaceID("kept")])
        for artifact in files {
            let file = core.url(of: artifact)
            #expect(copy(of: file, in: core) == corrupt, "\(artifact)")
            #expect(try Data(contentsOf: file) != corrupt, "\(artifact)")
        }
    }

    @Test("a corrupt profile is kept, then written")
    func profileFile() throws {
        let dir = try scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        let core = makeTestCore(configDirectory: dir)
        let file = try core.profiles.fileURL(name: "Desk")
        try spoil(file)
        try core.profiles.write(profile("Desk"))
        #expect(copy(of: file, in: core) == corrupt)
        #expect(try core.profiles.read(name: "Desk").name == "Desk")
    }

    @Test("a corrupt library is kept, then written")
    func libraries() throws {
        let dir = try scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        let core = makeTestCore(configDirectory: dir)
        try spoil(core.paletteLibrary.url)
        try spoil(core.lookLibrary.url)
        try core.paletteLibrary.save(
            ColorPalette(name: "Mine", colors: [:])
        )
        try core.lookLibrary.save(
            ShelfLook(name: "Mine", style: [:], colors: [:])
        )
        #expect(core.paletteLibrary.userPalettes().map(\.name) == ["Mine"])
        #expect(core.lookLibrary.userLooks().map(\.name) == ["Mine"])
        #expect(copy(of: core.paletteLibrary.url, in: core) == corrupt)
        #expect(copy(of: core.lookLibrary.url, in: core) == corrupt)
    }

    @Test("a profile's copy never shares a store file's name")
    func profileCopyIsItsOwn() throws {
        let dir = try scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        let core = makeTestCore(configDirectory: dir)
        let profileFile = try core.profiles.fileURL(name: "gui")
        try spoil(profileFile)
        try spoil(core.url(of: .guiConfig))
        let other = Data("[ also broken".utf8)
        try other.write(to: profileFile)
        try core.guiConfigStore.save(GuiConfig())
        try core.profiles.write(profile("gui"))
        #expect(copy(of: core.url(of: .guiConfig), in: core) == corrupt)
        #expect(copy(of: profileFile, in: core) == other)
    }

    @Test("a readable file leaves no copy")
    func readableFileKeepsNone() throws {
        let dir = try scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        let core = makeTestCore(configDirectory: dir)
        try core.guiConfigStore.save(GuiConfig())
        try core.guiConfigStore.save(GuiConfig())
        try core.profiles.write(profile("Desk"))
        try core.profiles.write(profile("Desk"))
        let mine = ColorPalette(name: "Mine", colors: [:])
        try core.paletteLibrary.save(mine)
        try core.paletteLibrary.save(mine)
        let files = [
            core.url(of: .guiConfig), core.url(of: .machineConfig),
            try core.profiles.fileURL(name: "Desk"),
            core.paletteLibrary.url,
        ]
        for file in files {
            #expect(copy(of: file, in: core) == nil, "\(file)")
        }
    }
}
