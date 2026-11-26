import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Use Current Wallpaper and the doors around a worn picture
/// (#3478): what each screen shows is stored, one picture where they
/// agree and one per screen where they differ; a re-wear sets the
/// picture again; a follower carries it.
@Suite("Look wallpaper current")
@MainActor
struct LookWallpaperCurrentTests {
    /// A core on `count` screens, each showing what `shown` answers
    /// for its display id.
    private func core(
        screens count: Int,
        shown: @escaping @MainActor (DisplayID) -> URL?
    ) -> (KiwiCore, Sets) {
        let core = makeTestCore()
        for index in 0..<count {
            core.state.workspaces.upsertDisplay(
                Display(
                    id: DisplayID(UInt32(index + 1)),
                    name: "S\(index)",
                    frame: CGRect(
                        x: CGFloat(index) * 1440,
                        y: 0,
                        width: 1440,
                        height: 900
                    )
                )
            )
        }
        let sets = Sets()
        core.lookWallpaperSeams.desk = WallpaperDesk(
            current: shown,
            set: { url, _ in
                sets.urls.append(url)
                return true
            }
        )
        core.lookWallpaperSeams.armed = true
        return (core, sets)
    }

    final class Sets { var urls: [URL] = [] }

    /// A picture file outside KiwiDesk's folders.
    private func foreignPicture(side: Int) throws -> URL {
        let url =
            testTemporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".png")
        try WallpaperLibraryTests.png(side).write(to: url)
        return url
    }

    @Test("screens showing one file store one picture")
    func oneFileIsAll() async throws {
        let file = try foreignPicture(side: 8)
        let (core, _) = core(screens: 2) { _ in file }
        _ = try core.saveLook(named: "Dusk", from: core.tiler.settings)
        let outcomes = await core.useCurrentWallpaper(for: "Dusk")
        #expect(outcomes == [1: .stored, 2: .stored])
        let held = try #require(core.userLooks.first?.wallpaper)
        guard case .all(let name) = held else {
            Issue.record("expected one picture, got \(held)")
            return
        }
        #expect(core.wallpaperLibrary.has(name))
    }

    @Test("screens showing different files store one each")
    func differentFilesArePerScreen() async throws {
        let first = try foreignPicture(side: 8)
        let second = try foreignPicture(side: 9)
        let (core, _) = core(screens: 2) {
            $0 == DisplayID(1) ? first : second
        }
        _ = try core.saveLook(named: "Dusk", from: core.tiler.settings)
        _ = await core.useCurrentWallpaper(for: "Dusk")
        let held = try #require(core.userLooks.first?.wallpaper)
        guard case .perScreen(let map) = held else {
            Issue.record("expected a per-screen map, got \(held)")
            return
        }
        #expect(Set(map.keys) == [1, 2])
        #expect(map[1] != map[2])
    }

    @Test("a screen with no picture file is named, never stored")
    func noFileIsNamed() async throws {
        let (core, _) = core(screens: 1) { _ in nil }
        _ = try core.saveLook(named: "Dusk", from: core.tiler.settings)
        #expect(
            await core.useCurrentWallpaper(for: "Dusk") == [1: .notPictureFile]
        )
        #expect(core.userLooks.first?.wallpaper == nil)
    }

    @Test("KiwiDesk's own copy is known by its URL, with no read")
    func ownCopyIsKnown() async throws {
        var shown: URL?
        let (core, _) = core(screens: 1) { _ in shown }
        let name = try core.wallpaperLibrary.add(WallpaperLibraryTests.png())
        shown = core.wallpaperCopies.url(of: name)
        _ = try core.saveLook(named: "Dusk", from: core.tiler.settings)
        #expect(await core.useCurrentWallpaper(for: "Dusk") == [1: .stored])
        #expect(core.userLooks.first?.wallpaper == .all(name))
    }

    @Test("re-wearing the worn look sets its picture again")
    func reWearSets() throws {
        let (core, sets) = core(screens: 1) { _ in nil }
        let name = try core.wallpaperLibrary.add(WallpaperLibraryTests.png())
        let look = ShelfLook(
            name: "Dusk",
            style: [:],
            colors: [:],
            wallpaper: .all(name)
        )
        core.wearLook(look)
        core.wearLook(look)
        #expect(sets.urls.count == 2)
    }

    @Test("a follower's copy is stamped with the picture")
    func followerIsStamped() {
        let picture = LookWallpaper.all(LookWallpaperTests.a)
        let body = LookBody(
            style: ["gap.global": .number(4)],
            colors: [:],
            wallpaper: picture
        )
        let worn = body.worn(over: TilingSettings())
        #expect(worn.lookWallpaper == picture)
        #expect(body.isStamped(on: worn))
        #expect(!body.isStamped(on: TilingSettings()))
        #expect(LookBody(of: worn).wallpaper == picture)
    }
}
