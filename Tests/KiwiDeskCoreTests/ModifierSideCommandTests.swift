import Foundation
import Testing

@testable import KiwiDeskCore

/// `set_modifier_sides` (#2601): the Mac's switch, `gui.json`'s
/// `modifier.sides`, reaching the keybinding manager live, and
/// read again from `init.lua` at a Lua-owned reload.
@Suite("Modifier sides switch (#2601)")
@MainActor
struct ModifierSideCommandTests {
    private func core() -> KiwiCore {
        makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("sides-\(UUID().uuidString)")
        )
    }

    @Test("the verb sets the switch and reaches the manager")
    func verbReachesTheManager() {
        let core = core()
        #expect(!core.appWide.modifierSides)
        #expect(
            core.execute("set_modifier_sides", args: [.bool(true)]).isSuccess
        )
        #expect(core.appWide.modifierSides)
        #expect(core.keys.modifierSides)
        #expect(
            core.execute("set_modifier_sides", args: [.bool(false)]).isSuccess
        )
        #expect(!core.keys.modifierSides)
        #expect(
            !core.execute("set_modifier_sides", args: [.string("maybe")])
                .isSuccess
        )
    }

    @Test("gui.json carries modifier.sides and reads it back")
    func storedShape() throws {
        var value = AppWideSettings()
        value.modifierSides = true
        var config = GuiConfig()
        config.appWide = value
        let data = try JSONEncoder().encode(config)
        let root = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let group = try #require(root["modifier"] as? [String: Any])
        #expect(group["sides"] as? Bool == true)
        let back = try JSONDecoder().decode(GuiConfig.self, from: data)
        #expect(back.appWide?.modifierSides == true)
        var bare = root
        bare["modifier"] = nil
        let old = try JSONDecoder().decode(
            GuiConfig.self,
            from: JSONSerialization.data(withJSONObject: bare)
        )
        #expect(old.appWide?.modifierSides == false)
    }

    @Test("a Lua-owned reload reads the switch init.lua sets now")
    func luaReload() throws {
        let core = core()
        let write = { (lua: String) in
            try FileManager.default.createDirectory(
                at: core.configURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try lua.write(
                to: core.configURL,
                atomically: true,
                encoding: .utf8
            )
            core.loadConfig()
        }
        try write("KiwiDesk.set_modifier_sides(true)\n")
        #expect(!core.isGuiManaged)
        #expect(core.keys.modifierSides)
        try write("-- off again\n")
        #expect(!core.keys.modifierSides)
    }
}
