import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Wearing a look's picture (#3478): the worn settings carry it beside
/// the origin, every install that changes it sets it through the one
/// hook, a launch is no wear, and attaching to the worn look sets it.
@Suite("Look wallpaper wear")
@MainActor
struct LookWallpaperWearTests {
    /// A core on one screen whose wallpaper reads and sets are
    /// recorded, armed as boot leaves it.
    private func core(armed: Bool = true) -> (KiwiCore, Box) {
        let core = makeTestCore()
        core.state.workspaces.upsertDisplay(
            Display(
                id: DisplayID(1),
                name: "Main",
                frame: CGRect(x: 0, y: 0, width: 1440, height: 900)
            )
        )
        let box = Box()
        core.lookWallpaperSeams.desk = WallpaperDesk(
            current: { _ in box.shown },
            set: { url, _ in
                box.sets.append(url)
                box.shown = url
                return true
            }
        )
        core.lookWallpaperSeams.armed = armed
        return (core, box)
    }

    final class Box {
        var shown: URL?
        var sets: [URL] = []
    }

    private func picture(in core: KiwiCore) throws -> String {
        try core.wallpaperLibrary.add(WallpaperLibraryTests.png())
    }

    @Test("a pick carries the picture beside the origin, not in it")
    func pickCarriesIt() {
        var settings = TilingSettings()
        let look = ShelfLook(
            name: "Dusk",
            style: [:],
            colors: [:],
            author: "Anna",
            wallpaper: .all(LookWallpaperTests.a)
        )
        look.pick(into: &settings)
        #expect(settings.lookWallpaper == .all(LookWallpaperTests.a))
        #expect(settings.lookOrigin?.wallpaper == nil)
        ShelfLook(name: "Mine", style: [:], colors: [:])
            .pick(into: &settings)
        #expect(settings.lookWallpaper == nil)
    }

    @Test("a picture never changes whether a look reads applied")
    func appliedIgnoresIt() {
        var settings = TilingSettings()
        let look = ShelfLook(
            name: "Dusk",
            style: ["gap.global": .number(4)],
            colors: [:]
        ).admitted
        look.apply(to: &settings)
        settings.lookWallpaper = .all(LookWallpaperTests.a)
        #expect(look.isApplied(to: settings))
    }

    @Test("wearing a look with a picture sets it on the screen")
    func wearSets() throws {
        let (core, box) = core()
        let name = try picture(in: core)
        ShelfLook(name: "Dusk", style: [:], colors: [:], wallpaper: .all(name))
            .pick(into: &core.tiler.settings)
        #expect(box.sets.map(\.lastPathComponent) == [name])
        #expect(core.wallpaperCopies.libraryName(of: box.sets[0]) == name)
    }

    @Test("a picture already shown is not set again")
    func shownIsSkipped() throws {
        let (core, box) = core()
        let name = try picture(in: core)
        box.shown = core.wallpaperCopies.url(of: name)
        #expect(core.setWallpaper(.all(name)) == [1: .alreadyShown])
        #expect(box.sets.isEmpty)
    }

    @Test("a launch is no wear")
    func bootSetsNothing() throws {
        let (core, box) = core(armed: false)
        let name = try picture(in: core)
        core.tiler.settings.lookWallpaper = .all(name)
        #expect(box.sets.isEmpty)
    }

    @Test("a look without a picture never touches the wallpaper")
    func noPictureSetsNothing() throws {
        let (core, box) = core()
        let name = try picture(in: core)
        core.tiler.settings.lookWallpaper = .all(name)
        box.sets = []
        core.tiler.settings.lookWallpaper = nil
        #expect(box.sets.isEmpty)
    }

    @Test("a picture not in the library is named, never set")
    func missingPicture() {
        let (core, box) = core()
        #expect(
            core.setWallpaper(.all(LookWallpaperTests.a)) == [1: .notInLibrary]
        )
        #expect(box.sets.isEmpty)
    }

    @Test("attaching to the worn look sets it at once")
    func attachToWorn() throws {
        let (core, box) = core()
        let look = try core.saveLook(named: "Dusk", from: core.tiler.settings)
        #expect(look.match(core.tiler.settings) == .applied)
        try core.chooseLookWallpaper(WallpaperLibraryTests.png(), for: "Dusk")
        #expect(box.sets.count == 1)
        #expect(core.tiler.settings.lookWallpaper != nil)
    }

    @Test("Remove detaches the picture and trashes what nothing names")
    func removeCleansUp() throws {
        let (core, _) = core()
        _ = try core.saveLook(named: "Dusk", from: core.tiler.settings)
        try core.chooseLookWallpaper(WallpaperLibraryTests.png(), for: "Dusk")
        let name = try #require(
            core.userLooks.first?.wallpaper?.names.first
        )
        try core.setLookWallpaper(nil, of: "Dusk")
        #expect(core.userLooks.first?.wallpaper == nil)
        #expect(core.tiler.settings.lookWallpaper == nil)
        #expect(!core.wallpaperLibrary.has(name))
    }

    @Test("an overwriting save keeps the look's picture")
    func saveKeepsIt() throws {
        let (core, _) = core()
        _ = try core.saveLook(named: "Dusk", from: core.tiler.settings)
        try core.chooseLookWallpaper(WallpaperLibraryTests.png(), for: "Dusk")
        let held = core.userLooks.first?.wallpaper
        _ = try core.saveLook(named: "Dusk", from: TilingSettings())
        #expect(core.userLooks.first?.wallpaper == held)
    }

    @Test("deleting the look trashes its picture")
    func deleteCleansUp() throws {
        let (core, _) = core()
        _ = try core.saveLook(named: "Dusk", from: core.tiler.settings)
        try core.chooseLookWallpaper(WallpaperLibraryTests.png(), for: "Dusk")
        let name = try #require(core.userLooks.first?.wallpaper?.names.first)
        core.tiler.settings.lookWallpaper = nil
        try core.deleteLook("Dusk")
        #expect(!core.wallpaperLibrary.has(name))
    }

    @Test("an export leaves the picture behind unless asked")
    func exportAsks() throws {
        let (core, _) = core()
        _ = try core.saveLook(named: "Dusk", from: core.tiler.settings)
        try core.chooseLookWallpaper(WallpaperLibraryTests.png(), for: "Dusk")
        let look = try #require(core.userLooks.first)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        try core.exportLook(look, to: url)
        #expect(!core.lookFileCarriesWallpaper(at: url))
        let plain = try LookStore.importLook(data: Data(contentsOf: url))
        #expect(plain.wallpaper == nil)
        try core.exportLook(look, to: url, includingWallpaper: true)
        #expect(core.lookFileCarriesWallpaper(at: url))
        let imported = try core.importLook(from: url, fallbackName: "X")
        #expect(imported.wallpaper == look.wallpaper)
        let without = try core.importLook(
            from: url,
            fallbackName: "X",
            withWallpaper: false
        )
        #expect(without.wallpaper == nil)
    }
}
