import Foundation
import Testing

@testable import KiwiDeskCore

/// A look's picture on the way between Macs (#3478): a restore
/// writes a bundle's pictures, a backup carries only what a look
/// names, and the sweep spares a picture inside its grace.
@Suite("Look wallpaper travel")
@MainActor
struct LookWallpaperTravelTests {
    @Test("a backup carries only the pictures a look names")
    func backupCarriesNamed() throws {
        let core = makeTestCore()
        let named = try core.wallpaperLibrary.add(WallpaperLibraryTests.png(8))
        let stray = try core.wallpaperLibrary.add(WallpaperLibraryTests.png(9))
        try core.lookLibrary.save(
            ShelfLook(
                name: "Dusk",
                style: [:],
                colors: [:],
                wallpaper: .all(named)
            )
        )
        let bundle = try core.exportSetup()
        #expect(bundle.wallpapers.map { Set($0.keys) } == [named])
        #expect(bundle.wallpapers?[stray] == nil)
    }

    @Test("a restore writes the bundle's pictures under their hash")
    func restoreWrites() throws {
        let source = makeTestCore()
        let name = try source.wallpaperLibrary.add(WallpaperLibraryTests.png())
        try source.lookLibrary.save(
            ShelfLook(
                name: "Dusk",
                style: [:],
                colors: [:],
                wallpaper: .all(name)
            )
        )
        let bundle = try source.exportSetup()
        let target = makeTestCore()
        _ = try target.restoreSetup(from: bundle) {
            try FileManager.default.removeItem(at: $0)
        }
        #expect(target.wallpaperLibrary.has(name))
        #expect(target.userLooks.first?.wallpaper == .all(name))
    }

    @Test("the sweep spares a picture inside its grace")
    func sweepGrace() throws {
        let core = makeTestCore()
        let name = try core.wallpaperLibrary.add(WallpaperLibraryTests.png())
        core.sweepWallpapers()
        #expect(core.wallpaperLibrary.has(name))
        core.wallClock = { Date().addingTimeInterval(8 * 24 * 3600) }
        core.sweepWallpapers()
        #expect(!core.wallpaperLibrary.has(name))
    }

    @Test("the sweep never trashes a named picture")
    func sweepKeepsNamed() throws {
        let core = makeTestCore()
        let name = try core.wallpaperLibrary.add(WallpaperLibraryTests.png())
        core.tiler.settings.lookWallpaper = .all(name)
        core.wallClock = { Date().addingTimeInterval(8 * 24 * 3600) }
        core.sweepWallpapers()
        #expect(core.wallpaperLibrary.has(name))
    }
}
