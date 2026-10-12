import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The Lua editor never saves a buffer over an init.lua edited
/// outside Settings since the buffer was loaded (#2206): a dirty
/// buffer refuses, a clean one re-reads the file.
@Suite("Lua editor stale save (#2206)", .serialized)
@MainActor
struct LuaEditorStaleSaveTests {
    /// Managed vocabulary outside the managed block: the live
    /// page opens on the forced Lua editor.
    private let foreign = "KiwiDesk.bind(\"cmd+1\", function() end)"

    private func makeModel() throws -> SettingsModel {
        let core = makeTestCore()
        try core.guiConfigStore.save(GuiConfig())
        try write(foreign, to: core)
        let model = makeTestModel(core: core)
        model.reload()
        return model
    }

    private func write(_ source: String, to core: KiwiCore) throws {
        try source.write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
    }

    private func onDisk(_ model: SettingsModel) throws -> String {
        try String(contentsOf: model.core.configURL, encoding: .utf8)
    }

    @Test("A dirty buffer refuses to overwrite an outside edit")
    func dirtyBufferRefuses() throws {
        let model = try makeModel()
        #expect(model.editingLua)
        model.luaSource = foreign + "\n-- mine"
        let outside = foreign + "\n-- theirs"
        try write(outside, to: model.core)

        model.saveLuaSource()

        #expect(try onDisk(model) == outside)
        #expect(model.profileWarning != nil)
    }

    @Test("A clean buffer re-reads the file when Settings is key")
    func cleanBufferReloads() throws {
        let model = try makeModel()
        let outside = foreign + "\n-- theirs"
        try write(outside, to: model.core)

        model.refreshOwner()

        #expect(model.editingLua)
        #expect(model.luaSource == outside)
    }

    @Test("An unchanged file takes the buffer")
    func unchangedFileSaves() throws {
        let model = try makeModel()
        let mine = foreign + "\n-- mine"
        model.luaSource = mine

        model.saveLuaSource()

        #expect(try onDisk(model) == mine)
        #expect(model.profileWarning == nil)
    }

    /// The refusal is drawn wherever the Lua editor's Save can
    /// fire: General opens that editor on a profileless page,
    /// where the header's profile rows stay hidden.
    @Test("the header draws the warning in the Lua editor")
    func warningIsDrawnInTheEditor() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/SettingsHeaderBar.swift"
            )
        let raw = try String(contentsOf: url, encoding: .utf8)
        #expect(!raw.isEmpty)
        let squashed = SourceScan.stripComments(raw)
            .split(whereSeparator: \.isWhitespace).joined()
        #expect(
            squashed.contains(
                "ifshowsProfileContext||model.editingLua,"
                    + "letwarning=model.profileWarning"
                    + "{warningRow(warning)}"
            )
        )
    }
}
