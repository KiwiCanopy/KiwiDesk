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
        #expect(core.unsavedWornLook() == nil)
    }

    @Test("a tweak to the worn look is the Current card")
    func tweakIsCurrent() throws {
        let core = makeCore()
        core.wearPickedLook(try other(core)) {}
        core.tiler.settings.borderStyle.focusedColor = "#123456"
        #expect(core.wornLibraryLook == nil)
        let current = try #require(core.unsavedWornLook())
        #expect(current.match(core.tiler.settings) == .applied)
    }

    /// An unreadable library could hold the worn look, so no card
    /// calls it unsaved and ⌘S has nothing to save over it.
    @Test("an unreadable library offers no Current card")
    func unreadableLibrary() throws {
        let core = makeCore()
        core.tiler.settings.borderStyle.focusedColor = "#123456"
        let url = core.lookLibrary.url
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(#"{"format": 99, "looks": []}"#.utf8).write(to: url)
        #expect(core.wornLibraryLook == nil)
        #expect(core.unsavedWornLook() == nil)
    }

    @Test("an unreadable library names no worn look")
    func unreadableNamesNone() throws {
        let core = makeCore()
        core.wearPickedLook(try other(core)) {}
        #expect(core.wornLibraryLook != nil)
        let url = core.lookLibrary.url
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(#"{"format": 99, "looks": []}"#.utf8).write(to: url)
        #expect(core.wornLibraryLook == nil)
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
        #expect(core.unsavedWornLook() == nil)
        #expect(core.wornLibraryLook != nil)
    }

    @Test("a picker rename answers the stored name and tells readers")
    func renameTellsReaders() throws {
        let core = makeCore()
        core.tiler.settings.borderStyle.focusedColor = "#123456"
        let saved = try core.saveWornLook(base: "Kiwi")
        var changed = 0
        core.onLookLibraryChanged = { changed += 1 }
        let stored = try core.renamePickedLook(
            from: saved.name,
            to: "  Night "
        )
        #expect(stored == "Night")
        #expect(changed == 1)
        #expect(core.userLooks.map(\.name).contains("Night"))
        #expect(throws: (any Error).self) {
            try core.renamePickedLook(
                from: "Night",
                to: LookCatalog.defaultName
            )
        }
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
