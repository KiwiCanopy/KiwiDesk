import Foundation
import Testing

@testable import KiwiDeskCore

/// What Settings lists as "Live, not saved" (#2262): the live
/// settings with each leaf the keep judgement calls unsaved put
/// back to its stored value — keepable and not stored, so a leaf
/// no keep can write is never listed.
@Suite("Unsaved live settings", .serialized)
@MainActor
struct UnsavedLiveSettingsTests {
    @Test("live as stored lists nothing")
    func cleanListsNothing() throws {
        let core = try KeepFixture.core()
        #expect(core.savedSettingsBehindLive() == nil)
    }

    @Test("a live change puts back only its own leaf")
    func liveChangeIsPutBack() throws {
        let core = try KeepFixture.core()
        try core.profiles.save(KeepFixture.profile("Odd"))
        KeepFixture.load("Odd", core)
        let stored = core.tiler.settings.borderStyle.width
        #expect(
            core.execute("border.set_width", args: [.number(9)])
                .isSuccess
        )
        let saved = try #require(core.savedSettingsBehindLive())
        #expect(saved.borderStyle.width == stored)
        var relive = saved
        relive.borderStyle.width = 9
        #expect(relive == core.tiler.settings)
    }

    @Test("a follower's look leaf is unsaved against the shared look")
    func followerLookLeaf() throws {
        let core = try KeepFixture.core()
        let stored = core.tiler.settings.borderStyle.width
        _ = core.execute("border.set_width", args: [.number(9)])
        let saved = try #require(core.savedSettingsBehindLive())
        #expect(saved.borderStyle.width == stored)
    }

    @Test("a value set back is saved again")
    func setBackListsNothing() throws {
        let core = try KeepFixture.core()
        let stored = core.tiler.settings.borderStyle.width
        _ = core.execute("border.set_width", args: [.number(9)])
        _ = core.execute(
            "border.set_width",
            args: [.number(Double(stored))]
        )
        #expect(core.savedSettingsBehindLive() == nil)
    }

    @Test("a leaf no keep can write is never listed")
    func unkeepableListsNothing() throws {
        let lua = try KeepFixture.core(gui: false)
        _ = lua.execute("border.set_width", args: [.number(9)])
        #expect(lua.savedSettingsBehindLive() == nil)

        let none = try KeepFixture.core()
        none.profiles.resetAdoption()
        _ = none.execute("border.set_width", args: [.number(9)])
        #expect(none.savedSettingsBehindLive() == nil)

        let appWide = try KeepFixture.core()
        _ = appWide.execute(
            "set_refusal_sound",
            args: [.bool(!appWide.appWide.refusalSound)]
        )
        #expect(appWide.savedSettingsBehindLive() == nil)
    }
}
