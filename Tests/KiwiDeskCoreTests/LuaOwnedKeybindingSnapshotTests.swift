import Foundation
import Testing

@testable import KiwiDeskCore

/// The live keybinding snapshot under Lua ownership (#2482): an
/// `init.lua` that binds keys lists them, and which owner the
/// snapshot answers for is the one the last LOAD applied, never
/// the file as it reads now.
@Suite("Lua-owned keybinding snapshot (#2482)", .serialized)
@MainActor
struct LuaOwnedKeybindingSnapshotTests {
    private static let inlineAndNamed = """
        local function lonely() KiwiDesk.focus("up") end
        KiwiDesk.bind("ctrl+alt+h", function()
          KiwiDesk.focus("left")
        end)
        KiwiDesk.bind("ctrl+alt+u", lonely)
        """

    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-lua-keys-\(UUID().uuidString)"
                )
        )
        var config = GuiConfig()
        config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [
                    KeyBinding(
                        combo: "ctrl+alt+j",
                        lua: "KiwiDesk.focus(\"down\")",
                        kind: .navigation
                    )
                ]
            )
        ]
        try? core.guiConfigStore.save(config)
        return core
    }

    private func writeInitLua(_ content: String, core: KiwiCore) throws {
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        try content.write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
    }

    private func bodies(_ snapshot: LiveKeybindingSnapshot) -> [String] {
        snapshot.keyLayers
            .first { $0.name == snapshot.activeLayerName }?
            .bindings.map(\.lua) ?? []
    }

    @Test("an init.lua that binds keys lists them, unread ones apart")
    func luaOwnedListsItsBindings() throws {
        let core = makeCore()
        try writeInitLua(Self.inlineAndNamed, core: core)
        core.loadConfig()

        let snapshot = try #require(core.liveKeybindingSnapshot())
        #expect(snapshot.isLuaOwned)
        #expect(bodies(snapshot) == ["KiwiDesk.focus(\"left\")"])
        let unread = snapshot.unreadChords(in: snapshot.activeLayerName)
        #expect(unread.count == 1)
        #expect(unread.first.flatMap(KeyCombo.parse) != nil)
    }

    @Test("Import stays drop-only: an unread chord never becomes a row")
    func importDropsTheUnreadChord() throws {
        let core = makeCore()
        try writeInitLua(Self.inlineAndNamed, core: core)
        core.loadConfig()

        let rows = core.recoverKeybindings().flatMap(\.bindings)
        #expect(rows.map(\.lua) == ["KiwiDesk.focus(\"left\")"])
        #expect(rows.allSatisfy { !$0.lua.isEmpty })
    }

    @Test("a Lua load stays Lua-owned after init.lua is emptied")
    func luaLoadIgnoresAnUnreloadedEdit() throws {
        let core = makeCore()
        try writeInitLua(Self.inlineAndNamed, core: core)
        core.loadConfig()
        try writeInitLua("", core: core)

        #expect(core.isGuiManaged)
        let snapshot = try #require(core.liveKeybindingSnapshot())
        #expect(snapshot.isLuaOwned)
        #expect(bodies(snapshot) == ["KiwiDesk.focus(\"left\")"])
    }

    @Test("a GUI load stays GUI-owned after init.lua gains a bind")
    func guiLoadIgnoresAnUnreloadedEdit() throws {
        let core = makeCore()
        try writeInitLua("", core: core)
        core.loadConfig()
        try writeInitLua(Self.inlineAndNamed, core: core)

        #expect(!core.isGuiManaged)
        let snapshot = try #require(core.liveKeybindingSnapshot())
        #expect(!snapshot.isLuaOwned)
        #expect(bodies(snapshot) == ["KiwiDesk.focus(\"down\")"])
    }
}
