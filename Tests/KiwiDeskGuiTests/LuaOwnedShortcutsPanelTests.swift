import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// KiwiHub's Shortcuts side over an `init.lua` that binds keys
/// (#2482), driven through `buildReference()` so the classify step
/// and the unread hand-off are read at the call site, not only in
/// the builder. With no `gui.json`, so the Space context must come
/// from live state. `.serialized` mirrors the sibling suites
/// (`LocalizationManager` is a process-wide singleton).
@Suite("Lua-owned shortcuts panel (#2482)", .serialized)
@MainActor
struct LuaOwnedShortcutsPanelTests {
    private static let source = """
        local function lonely() KiwiDesk.focus_space_next() end
        KiwiDesk.bind("ctrl+alt+n", function()
          KiwiDesk.focus_space_next()
        end)
        KiwiDesk.bind("ctrl+alt+u", lonely)
        KiwiDesk.bind("ctrl+alt+s", function()
          KiwiDesk.focus_or_spawn("com.apple.Safari")
        end)
        """

    private func loadedCore() throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-lua-panel-\(UUID().uuidString)"
                )
        )
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        try Self.source.write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
        core.loadConfig()
        return core
    }

    @Test("a known inline body files in its band, not Custom")
    func knownBodyFilesInItsBand() throws {
        LocalizationManager.shared.select("en")
        let core = try loadedCore()
        let reference = try #require(
            JumpPanelController(core: core).buildReference()
        )
        let ids = reference.controls.flatMap(\.rows).map(\.id)
        #expect(ids.contains("KiwiDesk.focus_space_next()"))
        #expect(
            !reference.custom.map(\.label)
                .contains("KiwiDesk.focus_space_next()")
        )
    }

    @Test("an app body files under Apps, which reads the kind")
    func appBodyFilesUnderApps() throws {
        LocalizationManager.shared.select("en")
        let core = try loadedCore()
        let reference = try #require(
            JumpPanelController(core: core).buildReference()
        )
        #expect(reference.apps.contains { $0.bundleID == "com.apple.Safari" })
    }

    @Test("an unread chord reaches Custom as a Lua function")
    func unreadChordReachesCustom() throws {
        LocalizationManager.shared.select("en")
        let core = try loadedCore()
        let reference = try #require(
            JumpPanelController(core: core).buildReference()
        )
        #expect(reference.custom.map(\.label) == ["Lua function"])
        #expect(
            reference.custom.first?.combo
                == ShortcutsReferenceBuilder.glyphs("ctrl+alt+u")
        )
    }

    @Test("a live chord hint reads the Lua binding")
    func chordHintReadsLua() throws {
        let core = try loadedCore()
        #expect(
            ShortcutsOpenBinding.combo(
                core: core,
                lua: "KiwiDesk.focus_space_next()"
            ) == KeyCombo.parse("ctrl+alt+n")
        )
    }
}
