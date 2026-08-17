import Foundation
import Testing

@testable import KiwiDeskCore

/// What a backup **refuses** — the pre-flight `readBackup` checks,
/// and the one export that must not proceed (#606).
///
/// Split from `SetupBundleTests` at §2.1's ceiling, on the seam
/// that file's own MARK already drew: that suite asks what a
/// bundle carries, this asks what is turned away and why.
@Suite("Setup backup: what it refuses (#606)")
@MainActor
struct SetupBundleRefusalTests {
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

    /// The **other** side of the comparison, which had no fixture
    /// until a `guard-prover` round narrowed `isReadable` from
    /// `<=` to `==` and watched all 18 tests stay green
    /// (2026-08-17).
    ///
    /// It reds **today** on exactly that narrowing — a prover
    /// round confirmed it, against an earlier draft of this
    /// comment that claimed it could not yet fire. What it buys
    /// beyond today is the day the format becomes 2: the same
    /// one-character regression would otherwise refuse every
    /// 1.0-era backup with `newerFormat(found: 1, supported: 2)`,
    /// a message that is nonsense on its face. The relation is
    /// what is asserted, so it keeps working as the number moves.
    @Test("An OLDER format still reads — upgrading keeps backups")
    func olderFormatIsAccepted() throws {
        let core = makeTestCore()
        let older = SetupBundle.currentFormat - 1
        let url = try write(
            """
            {"format":\(older),"writtenBy":"0.0.1",
             "profiles":[],
             "palettes":[{"name":"Mine","colors":{}}]}
            """,
            in: core
        )

        let bundle = try core.readBackup(at: url)
        #expect(bundle.format == older)
        #expect(bundle.palettes.count == 1)
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

    @Test("A corrupt settings file refuses the export")
    func corruptSidecarRefusesExport() throws {
        let core = makeTestCore()
        try core.guiConfigStore.save(GuiConfig())
        // A sidecar that EXISTS and will not decode. Through
        // `load()` alone this is indistinguishable from a
        // Lua-owned Mac with no sidecar at all, and the two want
        // opposite answers: one is a legitimate profiles-only
        // backup, the other is a backup silently missing every
        // setting the user made.
        try "not json".write(
            to: core.guiConfigStore.url,
            atomically: true,
            encoding: .utf8
        )

        #expect(throws: SetupBundleError.unreadableSettings) {
            try core.writeBackup(
                to: core.configDirectory
                    .appendingPathComponent("b.json")
            )
        }
    }

    @Test("No sidecar at all still exports, and says so by omission")
    func absentSidecarStillExports() throws {
        let core = makeTestCore()
        try core.profiles.save(profile("Desk"))
        #expect(!core.guiConfigStore.exists)

        // The benign half of the same nil: nothing to omit, so the
        // export proceeds and carries what there is.
        let url = core.configDirectory
            .appendingPathComponent("b.json")
        try core.writeBackup(to: url)
        #expect(try core.readBackup(at: url).config == nil)
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
