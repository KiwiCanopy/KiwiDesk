import Foundation
import Testing

@testable import KiwiDeskCore

/// KiwiHub's navigation key alternatives (`kiwihub.set_key`,
/// #2600): Lua-only, one chord per built-in key, refused where the
/// panel or the search field already answers the press.
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
        let keys = { core.tiler.settings.kiwihub.key }
        #expect(keys() == KiwiHubKeys())
        #expect(set(core, "down", "ctrl+n").isSuccess)
        #expect(set(core, "page_up", "ctrl+u").isSuccess)
        #expect(keys().down == "control+n")
        #expect(keys().pageUp == "control+u")
        #expect(set(core, "down", "").isSuccess)
        #expect(keys().down == nil)
        #expect(set(core, "page_up").isSuccess)
        #expect(keys().pageUp == nil)
    }

    @Test("an unknown key or an unreadable chord is refused")
    func refusesBadArguments() {
        let core = core()
        #expect(!set(core, "next", "ctrl+n").isSuccess)
        #expect(!set(core, "down", "ctrl+nope").isSuccess)
        #expect(core.tiler.settings.kiwihub.key == KiwiHubKeys())
    }

    @Test("a chord that types, the panel's own and Hyper are refused")
    func refusesWhatThePanelAnswers() {
        let core = core()
        for combo in [
            "n", "shift+n", "hyper+n", "ctrl+return", "alt+tab",
            "ctrl+down", "cmd+3", "cmd+s", "cmd+comma", "cmd+w",
            "cmd+v", "ctrl+escape",
        ] {
            #expect(!set(core, "down", combo).isSuccess, "\(combo)")
        }
        #expect(core.tiler.settings.kiwihub.key == KiwiHubKeys())
        // A ⌘ chord the panel does not keep is fine.
        #expect(set(core, "down", "cmd+j").isSuccess)
    }

    @Test("one chord serves one key; re-setting the same key is fine")
    func oneChordOneKey() {
        let core = core()
        #expect(set(core, "down", "ctrl+n").isSuccess)
        let taken = set(core, "up", "ctrl+n")
        #expect(!taken.isSuccess)
        #expect(taken.error == KiwiHubKeyRefusal.taken(.down).message)
        #expect(set(core, "down", "control+n").isSuccess)
    }

    @Test("the keys round-trip as kiwihub.key, sparse")
    func coding() throws {
        var settings = TilingSettings()
        settings.kiwihub.key.down = "control+n"
        settings.kiwihub.key.pageDown = "control+d"
        let data = try JSONEncoder().encode(settings)
        let root = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let hub = try #require(root["kiwihub"] as? [String: Any])
        let key = try #require(hub["key"] as? [String: String])
        #expect(key == ["down": "control+n", "page_down": "control+d"])
        let back = try JSONDecoder().decode(
            TilingSettings.self,
            from: data
        )
        #expect(back.kiwihub == settings.kiwihub)
    }

    @Test("a file without the group reads as no alternatives")
    func absentGroup() throws {
        let data = Data("{}".utf8)
        let settings = try JSONDecoder().decode(
            TilingSettings.self,
            from: data
        )
        #expect(settings.kiwihub == KiwiHubSettings())
    }
}
