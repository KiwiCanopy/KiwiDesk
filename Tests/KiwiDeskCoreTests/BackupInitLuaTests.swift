import Foundation
import Testing

@testable import KiwiDeskCore

/// `init.lua` in a backup is an opt-in on both ends (#2517): an
/// export carries it only when asked, a restore replaces this
/// Mac's only when asked and the backup carries one, and a
/// restore that replaces it is judged on the incoming file.
@Suite("Backup: init.lua opt-in (#2517)")
@MainActor
struct BackupInitLuaTests {
    private static let guiLua = "-- my notes\nprint('hello')\n"
    /// Binds a key itself, so `isGuiManaged` reads false.
    private static let foreignLua =
        "KiwiDesk.bind(\"ctrl-alt-x\", function() end)\n"

    private func core(initLua: String?) throws -> KiwiCore {
        let core = makeTestCore()
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        try core.guiConfigStore.save(GuiConfig())
        if let initLua {
            try initLua.write(
                to: core.configURL,
                atomically: true,
                encoding: .utf8
            )
        }
        return core
    }

    private func bundle(initLua: String?) -> SetupBundle {
        SetupBundle(
            writtenBy: "test",
            config: GuiConfig(),
            profiles: [],
            palettes: [],
            initLua: initLua
        )
    }

    private func lua(of core: KiwiCore) -> String? {
        try? String(contentsOf: core.configURL, encoding: .utf8)
    }

    @Test("an export carries init.lua only when asked")
    func exportIsOptIn() throws {
        let core = try core(initLua: Self.guiLua)
        #expect(try core.exportSetup().initLua == nil)
        #expect(
            try core.exportSetup(includingInitLua: true).initLua
                == Self.guiLua
        )
    }

    @Test("asked with no init.lua, the export carries none")
    func exportWithoutFile() throws {
        let core = try core(initLua: nil)
        #expect(
            try core.exportSetup(includingInitLua: true).initLua == nil
        )
    }

    @Test("the written file round-trips the carried init.lua")
    func writtenFileCarriesIt() throws {
        let core = try core(initLua: Self.guiLua)
        let url = core.configDirectory
            .appendingPathComponent("with-lua.json")
        try core.writeBackup(to: url, includingInitLua: true)
        #expect(try core.readBackup(at: url).initLua == Self.guiLua)
        try core.writeBackup(to: url)
        #expect(try core.readBackup(at: url).initLua == nil)
    }

    @Test("a plain restore leaves a carried init.lua alone")
    func plainRestoreLeavesIt() throws {
        let core = try core(initLua: Self.guiLua)
        var trashed: [String] = []
        let outcome = try core.restoreSetup(
            from: bundle(initLua: "-- theirs\n"),
            trash: { url in
                trashed.append(url.lastPathComponent)
                try FileManager.default.removeItem(at: url)
            }
        )
        #expect(outcome.initLua == .leftAlone)
        #expect(lua(of: core) == Self.guiLua)
        #expect(!trashed.contains("init.lua"))
    }

    @Test("asked, a restore trashes init.lua and writes the backup's")
    func askedRestoreReplacesIt() throws {
        let core = try core(initLua: Self.guiLua)
        var trashed: [String] = []
        let outcome = try core.restoreSetup(
            from: bundle(initLua: "-- theirs\n"),
            replacingInitLua: true,
            trash: { url in
                trashed.append(url.lastPathComponent)
                try FileManager.default.removeItem(at: url)
            }
        )
        #expect(outcome.initLua == .replaced)
        #expect(lua(of: core) == "-- theirs\n")
        #expect(trashed.contains("init.lua"))
    }

    @Test("asked, a backup with no init.lua leaves this Mac's")
    func askedWithoutCarried() throws {
        let core = try core(initLua: Self.guiLua)
        let outcome = try core.restoreSetup(
            from: bundle(initLua: nil),
            replacingInitLua: true,
            trash: { try FileManager.default.removeItem(at: $0) }
        )
        #expect(outcome.initLua == .notCarried)
        #expect(lua(of: core) == Self.guiLua)
    }

    @Test("a Lua-owned Mac refuses a plain restore, takes one with init.lua")
    func luaOwnedIsRejudged() throws {
        let core = try core(initLua: Self.foreignLua)
        #expect(!core.isGuiManaged)
        let carried = bundle(initLua: Self.guiLua)
        #expect(
            core.restoreChoices(for: carried)
                == RestoreChoices(
                    plainRefusal: .luaOwnsThisMac,
                    withInitLua: true
                )
        )
        #expect(
            throws: SetupBundleError.luaOwnsThisMac,
            performing: {
                try core.restoreSetup(
                    from: carried,
                    trash: { try FileManager.default.removeItem(at: $0) }
                )
            }
        )
        #expect(lua(of: core) == Self.foreignLua)
        try core.restoreSetup(
            from: carried,
            replacingInitLua: true,
            trash: { try FileManager.default.removeItem(at: $0) }
        )
        #expect(lua(of: core) == Self.guiLua)
        #expect(core.isGuiManaged)
    }

    @Test("the choices follow what the backup carries")
    func choicesOnAGuiMac() throws {
        let core = try core(initLua: nil)
        #expect(
            core.restoreChoices(for: bundle(initLua: nil))
                == RestoreChoices(plainRefusal: nil, withInitLua: false)
        )
        #expect(
            core.restoreChoices(for: bundle(initLua: Self.guiLua))
                == RestoreChoices(plainRefusal: nil, withInitLua: true)
        )
    }

    @Test("a Lua-owned Mac with nothing to take has no choice")
    func noChoiceWithoutCarried() throws {
        let core = try core(initLua: Self.foreignLua)
        #expect(!core.restoreChoices(for: bundle(initLua: nil)).any)
    }

    /// A restore taking an `init.lua` that owns the settings itself
    /// writes the backup's `gui.json` but does not apply it.
    @Test(
        "an incoming init.lua decides whether the settings apply",
        arguments: [true, false]
    )
    func incomingOwnershipGatesTheApply(guiOwned: Bool) throws {
        let core = try core(initLua: nil)
        var config = GuiConfig()
        config.settings.resizeStep = 77
        let carried = SetupBundle(
            writtenBy: "test",
            config: config,
            profiles: [],
            palettes: [],
            initLua: guiOwned ? Self.guiLua : Self.foreignLua
        )
        try core.restoreSetup(
            from: carried,
            replacingInitLua: true,
            trash: { try FileManager.default.removeItem(at: $0) }
        )
        #expect((core.tiler.settings.resizeStep == 77) == guiOwned)
    }

    /// Once init.lua is replaced, a failed write still reloads, so
    /// the core never runs the old setup over the new files.
    @Test("a failed write after the replace still reloads")
    func failedWriteStillReloads() throws {
        let core = try core(initLua: Self.guiLua)
        let broken = "this is not lua (\n"
        let carried = SetupBundle(
            writtenBy: "test",
            config: nil,
            profiles: [
                Profile(
                    name: "../outside",
                    monitorSets: [],
                    spaces: [SpaceID("1")],
                    spaceModes: [:],
                    settings: TilingSettings()
                )
            ],
            palettes: [],
            initLua: broken
        )
        #expect(core.configIssues.isEmpty)
        #expect(
            throws: SetupBundleError.self,
            performing: {
                try core.restoreSetup(
                    from: carried,
                    replacingInitLua: true,
                    trash: { try FileManager.default.removeItem(at: $0) }
                )
            }
        )
        #expect(lua(of: core) == broken)
        #expect(!core.configIssues.isEmpty)
    }

    /// A backup with nothing but init.lua restores only with it: a
    /// plain restore would empty this Mac and write nothing.
    @Test("an init.lua-only backup offers no plain restore")
    func initLuaOnlyBackup() throws {
        let core = try core(initLua: nil)
        let only = SetupBundle(
            writtenBy: "test",
            config: nil,
            profiles: [],
            palettes: [],
            initLua: Self.guiLua
        )
        #expect(
            core.restoreChoices(for: only)
                == RestoreChoices(plainRefusal: .empty, withInitLua: true)
        )
        #expect(
            throws: SetupBundleError.empty,
            performing: {
                try core.restoreSetup(
                    from: only,
                    trash: { try FileManager.default.removeItem(at: $0) }
                )
            }
        )
        // Taken with init.lua, it lands the source's setup whole:
        // profiles and palettes replaced with none (#606's ruling).
        try core.profiles.save(
            Profile(
                name: "Here",
                monitorSets: [],
                spaces: [SpaceID("1")],
                spaceModes: [:],
                settings: TilingSettings()
            )
        )
        try core.restoreSetup(
            from: only,
            replacingInitLua: true,
            trash: { try FileManager.default.removeItem(at: $0) }
        )
        #expect(core.profiles.allProfiles().isEmpty)
        #expect(lua(of: core) == Self.guiLua)
    }
}
