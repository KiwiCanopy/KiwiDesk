import Foundation
import Testing

@testable import KiwiDeskCore

/// What Settings lists as "Live, not saved" (#2262): the live
/// settings beside a copy with each leaf the keep judgement calls
/// unsaved put back to its stored value — keepable and not stored,
/// so a leaf no keep can write is never listed.
@Suite("Unsaved live settings", .serialized)
@MainActor
struct UnsavedLiveSettingsTests {
    /// A core whose live profile keeps its own look.
    private func ownLookCore() throws -> KiwiCore {
        let core = try KeepFixture.core()
        try core.profiles.save(KeepFixture.profile("Odd"))
        KeepFixture.load("Odd", core)
        return core
    }

    @Test("live as stored lists nothing")
    func cleanListsNothing() throws {
        let core = try KeepFixture.core()
        #expect(core.unsavedLiveSettings() == nil)
    }

    @Test("a live change puts back only its own leaf")
    func liveChangeIsPutBack() throws {
        let core = try ownLookCore()
        let stored = core.tiler.settings.borderStyle.width
        #expect(
            core.execute("border.set_width", args: [.number(9)])
                .isSuccess
        )
        let unsaved = try #require(core.unsavedLiveSettings())
        #expect(unsaved.live == core.tiler.settings)
        #expect(unsaved.saved.borderStyle.width == stored)
        var relive = unsaved.saved
        relive.borderStyle.width = 9
        #expect(relive == unsaved.live)
    }

    @Test("a follower's look leaf is unsaved against the shared look")
    func followerLookLeaf() throws {
        let core = try KeepFixture.core()
        let stored = core.tiler.settings.borderStyle.width
        _ = core.execute("border.set_width", args: [.number(9)])
        let unsaved = try #require(core.unsavedLiveSettings())
        #expect(unsaved.saved.borderStyle.width == stored)
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
        #expect(core.unsavedLiveSettings() == nil)
    }

    /// The Save the pill offers keeps every row it lists — the
    /// profile's own leaf and a follower's shared-look leaf alike.
    @Test("a Settings Save leaves nothing unsaved")
    func saveClears() throws {
        for core in [try ownLookCore(), try KeepFixture.core()] {
            _ = core.execute("border.set_width", args: [.number(9)])
            #expect(core.unsavedLiveSettings() != nil)
            let name = try #require(core.profiles.currentName)
            try core.persistProfile(named: name, modes: ["1": .bsp])
            #expect(core.unsavedLiveSettings() == nil)
        }
    }

    /// The keepability filter: a temporary Space's icon is a leaf
    /// no keep writes, while the same leaf on a declared Space is
    /// listed — the control that keeps this case from passing on
    /// an early return.
    @Test("a temporary Space's leaf is never listed")
    func temporarySpaceLeafIsNotListed() throws {
        let core = try ownLookCore()
        _ = core.execute("focus_space", args: [.string("8")])
        #expect(core.isTemporary(SpaceID("8")))
        _ = core.execute(
            "set_space_icon",
            args: [.string("8"), .string("star")]
        )
        #expect(core.unsavedLiveSettings() == nil)
        _ = core.execute(
            "set_space_icon",
            args: [.string("1"), .string("star")]
        )
        let unsaved = try #require(core.unsavedLiveSettings())
        #expect(unsaved.saved.spaceIcons[SpaceID("1")] == nil)
        #expect(unsaved.saved.spaceIcons[SpaceID("8")] == "star")
    }

    /// What an open draft takes when live moved under it: its own
    /// edits, leaf by leaf, over the settings live draws now.
    @Test("a draft rebased onto live keeps only its own edits")
    func rebaseKeepsEdits() {
        let base = TilingSettings()
        var draft = base
        draft.gapsGlobal.outer.top += 3
        var live = base
        live.borderStyle.width = 9
        let rebased = draft.rebased(from: base, onto: live)
        #expect(rebased.borderStyle.width == 9)
        #expect(rebased.gapsGlobal.outer.top == draft.gapsGlobal.outer.top)
        #expect(base.rebased(from: base, onto: live) == live)
    }

    @Test("with no store to keep into, nothing is listed")
    func noStoreListsNothing() throws {
        let lua = try KeepFixture.core(gui: false)
        _ = lua.execute("border.set_width", args: [.number(9)])
        #expect(lua.unsavedLiveSettings() == nil)

        let none = try KeepFixture.core()
        none.profiles.resetAdoption()
        _ = none.execute("border.set_width", args: [.number(9)])
        #expect(none.unsavedLiveSettings() == nil)
    }
}
