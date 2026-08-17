import Foundation
import Testing

@testable import KiwiDeskCore

/// What a backup carries, and what it refuses to read (#606).
///
/// `@MainActor` because `KiwiCore` is; the work is JSON.
@Suite("Setup backup: contents and validation (#606)")
@MainActor
struct SetupBundleTests {
    private func palette(_ name: String) -> ColorPalette {
        ColorPalette(
            name: name,
            colors: [ColorPaletteKeys.all[0]: "#112233"]
        )
    }

    private func profile(_ name: String) -> Profile {
        Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: ["A:100x100"])],
            spaces: [SpaceID("1")],
            spaceModes: [SpaceID("1"): .grid],
            settings: TilingSettings()
        )
    }

    private func write(_ text: String, in core: KiwiCore) throws
        -> URL
    {
        let url = core.configDirectory
            .appendingPathComponent("probe.json")
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - What travels

    @Test("The palette library travels, which gui.json cannot carry")
    func exportCarriesPalettes() throws {
        let core = makeTestCore()
        try core.guiConfigStore.save(GuiConfig())
        try core.paletteLibrary.save(palette("Mine"))

        let bundle = core.exportSetup()

        // The finding this feature turned on: applying a palette
        // writes its COLOURS into the settings, so the current
        // look rides gui.json — while the saved library lives in
        // palettes.json and would be left behind. The issue's own
        // bundle table guessed the opposite.
        #expect(bundle.palettes.map(\.name) == ["Mine"])
    }

    @Test("Every profile travels")
    func exportCarriesProfiles() throws {
        let core = makeTestCore()
        try core.profiles.save(profile("Desk"))
        try core.profiles.save(profile("Laptop"))

        let names = Set(core.exportSetup().profiles.map(\.name))
        #expect(names == ["Desk", "Laptop"])
    }

    @Test("A Lua-owned config still backs up what it has")
    func exportWithoutSidecarIsStillUseful() throws {
        let core = makeTestCore()
        try core.profiles.save(profile("Desk"))
        // No gui.json at all — the Lua-managed case, which is
        // ungated by owner ruling rather than hidden.
        #expect(!core.guiConfigStore.exists)

        let bundle = core.exportSetup()
        #expect(bundle.config == nil)
        #expect(bundle.profiles.count == 1)
        // And it is not "empty", so a restore of it is offered
        // rather than refused.
        #expect(!bundle.isEmpty)
    }

    @Test("A bundle round-trips through JSON unchanged")
    func roundTrips() throws {
        let core = makeTestCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("1"), SpaceID("code")]
        try core.guiConfigStore.save(config)
        try core.profiles.save(profile("Desk"))
        try core.paletteLibrary.save(palette("Mine"))

        let original = core.exportSetup()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            SetupBundle.self,
            from: data
        )
        #expect(decoded == original)
    }

    // MARK: - What it refuses

    @Test("A missing file is unreadable, not an empty backup")
    func missingFileIsUnreadable() {
        let core = makeTestCore()
        let missing = core.configDirectory
            .appendingPathComponent("nope.json")
        #expect(throws: SetupBundleError.unreadable) {
            try core.readBackup(at: missing)
        }
    }

    @Test("Valid JSON that is not a backup is refused")
    func foreignJSONIsRefused() throws {
        let core = makeTestCore()
        let url = try write(#"{"hello":"world"}"#, in: core)
        #expect(throws: SetupBundleError.notABackup) {
            try core.readBackup(at: url)
        }
    }

    @Test("A newer format is refused, naming both versions")
    func newerFormatIsRefused() throws {
        let core = makeTestCore()
        let future = SetupBundle.currentFormat + 1
        let url = try write(
            """
            {"format":\(future),"writtenBy":"9.9.9",
             "profiles":[],"palettes":[]}
            """,
            in: core
        )
        // The reason a format field exists at all: JSONDecoder is
        // lenient, so without this a future bundle would decode
        // with unknown fields dropped and report success having
        // silently lost data.
        #expect(
            throws: SetupBundleError.newerFormat(
                found: future,
                supported: SetupBundle.currentFormat
            )
        ) {
            try core.readBackup(at: url)
        }
    }

    @Test("A backup that would restore nothing is refused")
    func emptyBackupIsRefused() throws {
        let core = makeTestCore()
        let url = try write(
            """
            {"format":\(SetupBundle.currentFormat),
             "writtenBy":"0.9.6","profiles":[],"palettes":[]}
            """,
            in: core
        )
        // Exporting one is legitimate; restoring one is a wipe
        // wearing the clothes of a restore.
        #expect(throws: SetupBundleError.empty) {
            try core.readBackup(at: url)
        }
    }

    @Test("A written backup reads back")
    func writeThenRead() throws {
        let core = makeTestCore()
        try core.guiConfigStore.save(GuiConfig())
        try core.profiles.save(profile("Desk"))
        let url = core.configDirectory
            .appendingPathComponent("backup.json")

        try core.writeBackup(to: url)
        let read = try core.readBackup(at: url)

        #expect(read.profiles.map(\.name) == ["Desk"])
        #expect(read.format == SetupBundle.currentFormat)
        #expect(read.writtenBy == KiwiDeskVersion.semantic)
    }

    @Test("Writing somewhere impossible reports the file")
    func unwritableDestinationIsReported() throws {
        let core = makeTestCore()
        try core.guiConfigStore.save(GuiConfig())
        let url = URL(
            fileURLWithPath: "/no/such/directory/backup.json"
        )
        #expect(
            throws: SetupBundleError.couldNotWrite(
                name: "backup.json"
            )
        ) {
            try core.writeBackup(to: url)
        }
    }
}
