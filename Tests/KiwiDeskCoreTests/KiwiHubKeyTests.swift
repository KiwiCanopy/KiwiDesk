import Foundation
import Testing

@testable import KiwiDeskCore

/// KiwiHub's navigation key alternatives (`kiwihub.set_key`,
/// #2600): Lua-only and app-wide, one chord per built-in key,
/// refused where the panel or the search field already answers the
/// press.
@Suite("KiwiHub navigation keys (#2600)")
@MainActor
struct KiwiHubKeyTests {
    private func core() -> KiwiCore {
        makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwihub-keys-\(UUID().uuidString)")
        )
    }

    private func set(
        _ core: KiwiCore,
        _ key: String,
        _ combo: String? = nil
    ) -> CommandResponse {
        var args: [JSONValue] = [.string(key)]
        if let combo { args.append(.string(combo)) }
        return core.execute("kiwihub.set_key", args: args)
    }

    @Test("a chord is stored canonically, and cleared without one")
    func storesAndClears() {
        let core = core()
        let keys = { core.appWide.kiwiHubKeys }
        #expect(keys() == KiwiHubKeys())
        #expect(set(core, "down", "ctrl+n").isSuccess)
        #expect(set(core, "page_up", "cmd+alt+u").isSuccess)
        #expect(keys().down == "control+n")
        #expect(keys().pageUp == "option+command+u")
        #expect(set(core, "down", "").isSuccess)
        #expect(keys().down == nil)
        #expect(set(core, "page_up").isSuccess)
        #expect(keys().pageUp == nil)
    }

    @Test("a profile apply keeps the keys: they are app-wide")
    func survivesTheSettingsReplace() {
        let core = core()
        #expect(set(core, "down", "ctrl+n").isSuccess)
        core.tiler.settings = TilingSettings()
        #expect(core.appWide.kiwiHubKeys.down == "control+n")
    }

    @Test("an unknown key or an unreadable chord is refused")
    func refusesBadArguments() {
        let core = core()
        #expect(!set(core, "next", "ctrl+n").isSuccess)
        #expect(!set(core, "down", "ctrl+nope").isSuccess)
        #expect(core.appWide.kiwiHubKeys == KiwiHubKeys())
    }

    @Test("each refusal names its reason")
    func refusalsNameTheirReason() {
        let core = core()
        let cases: [(String, KiwiHubKeyRefusal)] = [
            ("n", .typesIntoField),
            ("shift+n", .typesIntoField),
            ("alt+n", .typesIntoField),
            ("hyper+ctrl+n", .hyper),
            ("ctrl+return", .panelKey),
            ("ctrl+enter", .panelKey),
            ("ctrl+keypadenter", .panelKey),
            ("ctrl+tab", .panelKey),
            ("ctrl+down", .panelKey),
            ("ctrl+pageup", .panelKey),
            ("ctrl+escape", .panelKey),
            ("cmd+3", .panelKey),
            ("cmd+s", .panelKey),
            ("cmd+comma", .panelKey),
            ("cmd+w", .panelKey),
            ("cmd+v", .panelKey),
        ]
        for (combo, refusal) in cases {
            #expect(
                set(core, "down", combo).error == refusal.message,
                "\(combo)"
            )
        }
        #expect(core.appWide.kiwiHubKeys == KiwiHubKeys())
        // A ⌘ chord the panel does not keep is fine.
        #expect(set(core, "down", "cmd+j").isSuccess)
    }

    @Test("one chord serves one key; re-setting the same key is fine")
    func oneChordOneKey() {
        let core = core()
        #expect(set(core, "down", "ctrl+n").isSuccess)
        let taken = set(core, "up", "ctrl+n")
        #expect(taken.error == KiwiHubKeyRefusal.taken(.down).message)
        #expect(set(core, "down", "control+n").isSuccess)
    }

    @Test("a stored chord the verb would refuse never answers")
    func refusedStoredChordIsInert() throws {
        var keys = KiwiHubKeys()
        keys.down = "n"
        keys.up = "control+return"
        keys.pageDown = "control+d"
        #expect(keys.key(for: try #require(KeyCombo.parse("n"))) == nil)
        #expect(
            keys.key(for: try #require(KeyCombo.parse("ctrl+return")))
                == nil
        )
        #expect(
            keys.key(for: try #require(KeyCombo.parse("ctrl+d")))
                == .pageDown
        )
    }

    @Test("every key round-trips through gui.json as kiwihub.key")
    func coding() throws {
        var value = AppWideSettings()
        for (index, key) in KiwiHubKey.allCases.enumerated() {
            value.kiwiHubKeys[key] = "control+\(index + 1)"
        }
        var config = GuiConfig()
        config.appWide = value
        let data = try JSONEncoder().encode(config)
        let root = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let hub = try #require(root["kiwihub"] as? [String: Any])
        let stored = try #require(hub["key"] as? [String: String])
        #expect(
            Set(stored.keys) == Set(KiwiHubKey.allCases.map(\.rawValue))
        )
        let back = try JSONDecoder().decode(GuiConfig.self, from: data)
        #expect(back.appWide?.kiwiHubKeys == value.kiwiHubKeys)
    }

    @Test("a gui.json without the group reads as no alternatives")
    func absentGroup() throws {
        var config = GuiConfig()
        config.appWide = AppWideSettings()
        let data = try JSONEncoder().encode(config)
        var root = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        root["kiwihub"] = nil
        let back = try JSONDecoder().decode(
            GuiConfig.self,
            from: JSONSerialization.data(withJSONObject: root)
        )
        #expect(back.appWide?.kiwiHubKeys == KiwiHubKeys())
    }

    @Test("a Lua-owned reload reads the keys init.lua sets now")
    func luaReloadReadsTheFile() throws {
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
        try write("kiwihub.set_key(\"down\", \"ctrl+n\")\n")
        #expect(!core.isGuiManaged)
        #expect(core.appWide.kiwiHubKeys.down == "control+n")
        try write("kiwihub.set_key(\"up\", \"ctrl+n\")\n")
        #expect(core.appWide.kiwiHubKeys.up == "control+n")
        #expect(core.appWide.kiwiHubKeys.down == nil)
        try write("-- no keys\n")
        #expect(core.appWide.kiwiHubKeys == KiwiHubKeys())
    }
}
