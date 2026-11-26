import Foundation
import Testing

@testable import KiwiDeskCore

/// The look picker's Core doors (#3038): ↩ wears a look for good —
/// live, written into the live profile, `ready` once — the worn
/// look is read once, an unsaved one is the Current card, and ⌘S
/// saves it under a free name.
@Suite("Look picker doors (#3038)", .serialized)
@MainActor
struct LookPickerCoreTests {
    private func makeCore() -> KiwiCore {
        let core = makeTestCore()
        _ = core.execute("save_profile", args: [.string("Mine")])
        return core
    }

    private func other(_ core: KiwiCore) throws -> ShelfLook {
        let worn = core.wornLibraryLook?.name
        return try #require(core.bundledLooks.first { $0.name != worn })
    }

    @Test("a wear is live, written through and ready once")
    func wearWritesThrough() throws {
        let core = makeCore()
        let look = try other(core)
        var readies = 0
        core.wearPickedLook(look) { readies += 1 }
        #expect(readies == 1)
        #expect(look.match(core.tiler.settings) == .applied)
        let stored = try core.profiles.read(name: "Mine").settings
        #expect(look.match(stored) == .applied)
        #expect(core.wornLibraryLook?.name == look.name)
        #expect(core.unsavedWornLook(named: "x") == nil)
    }

    @Test("a tweak to the worn look is the Current card")
    func tweakIsCurrent() throws {
        let core = makeCore()
        core.wearPickedLook(try other(core)) {}
        core.tiler.settings.borderStyle.focusedColor = "#123456"
        #expect(core.wornLibraryLook == nil)
        let current = try #require(core.unsavedWornLook(named: "Now"))
        #expect(current.name == "Now")
        #expect(current.match(core.tiler.settings) == .applied)
    }

    @Test("⌘S saves the worn look under a free name")
    func quickSaveTakesAFreeName() throws {
        let core = makeCore()
        core.tiler.settings.borderStyle.focusedColor = "#123456"
        var changed = 0
        core.onLookLibraryChanged = { changed += 1 }
        let first = try core.saveWornLook(base: "Kiwi · Nov 24")
        #expect(first.name == "Kiwi · Nov 24")
        let second = try core.saveWornLook(base: "Kiwi · Nov 24")
        #expect(second.name == "Kiwi · Nov 24 2")
        #expect(changed == 2)
        #expect(core.unsavedWornLook(named: "Now") == nil)
        #expect(core.wornLibraryLook != nil)
    }

    @Test("look.show_picker raises the GUI hook and moves nothing")
    func verbRaisesTheHook() {
        let core = makeCore()
        var shown = 0
        core.uiBridge.onLookShowPicker = { shown += 1 }
        let before = core.tiler.settings
        #expect(core.execute("look.show_picker").isSuccess)
        #expect(shown == 1)
        #expect(core.tiler.settings == before)
    }
}
