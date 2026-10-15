import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// KiwiVision's "Wallpaper" switch through a live core (#2103
/// rulings 17–21): stored app-wide as `kiwivision.clear_wallpaper`,
/// a verb a session value, and the plate masked to the windows below
/// it — the shown Spaces' members at the engine's frames, every
/// other app's window from the one list read, which runs only at a
/// settle pass or when nothing is cached.
@Suite("KiwiVision clear wallpaper")
@MainActor
struct KiwiVisionClearWallpaperTests {
    private let w1 = WindowID(1)

    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-vision-clear-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: w1, pid: 1, appName: "App1")
            )
        )
        let space = core.state.workspaces.space(of: w1)!
        core.state.workspaces.focus(w1, in: space)
        core.eventLoop.ownKeyWindow = { nil }
        return core
    }

    @Test("gui.json stores clear_wallpaper; its absence reads off")
    func storedShape() throws {
        var config = GuiConfig()
        var value = AppWideSettings()
        value.visionClearWallpaper = true
        config.appWide = value
        let data = try JSONEncoder().encode(config)
        let root = try #require(
            try JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        )
        let group = try #require(root["kiwivision"] as? [String: Any])
        #expect(group["clear_wallpaper"] as? Bool == true)
        let back = try JSONDecoder().decode(GuiConfig.self, from: data)
        #expect(back.appWide?.visionClearWallpaper == true)
        #expect(AppWideSettings().visionClearWallpaper == false)
    }

    @Test("the verb is a session value")
    func verbIsSession() throws {
        let core = makeCore()
        try core.guiConfigStore.save(GuiConfig())
        let reply = core.execute(
            "kiwivision.set_clear_wallpaper",
            args: [.bool(true)]
        )
        #expect(reply.isSuccess)
        #expect(core.appWide.visionClearWallpaper)
        #expect(core.guiConfigStore.load()?.appWide == nil)
        #expect(
            !core.execute("kiwivision.set_clear_wallpaper", args: [])
                .isSuccess
        )
    }

    @Test("off, or the mode off, the request carries no mask")
    func requestFollowsTheSwitch() {
        let core = makeCore()
        var reads = 0
        core.vision.listWindows = {
            reads += 1
            return []
        }
        core.setAppWide(persisting: false) {
            $0.visionClearWallpaper = true
        }
        #expect(!core.visionRequest().clearWallpaper, "mode off")
        core.vision.isOn = true
        #expect(core.visionRequest().clearWallpaper)
        core.setAppWide(persisting: false) {
            $0.visionClearWallpaper = false
        }
        let request = core.visionRequest()
        #expect(!request.clearWallpaper)
        #expect(request.windows.isEmpty)
        #expect(reads == 1, "only the request that masked read the list")
    }

    @Test("the mask takes the members' frames and other apps' windows")
    func maskWindows() {
        let core = makeCore()
        let tracked = CGRect(x: 10, y: 20, width: 300, height: 200)
        core.state.windows.updateFrame(w1, frame: tracked)
        let other = CGRect(x: 500, y: 40, width: 100, height: 100)
        core.vision.listWindows = {
            [
                VisionListedWindow(number: 99, frame: other),
                // A tracked window the list also names counts once.
                VisionListedWindow(number: 1, frame: .zero),
            ]
        }
        let frames = core.visionMaskWindows(refreshingList: true)
        let height = GeometryUtils.primaryHeight
        #expect(
            frames == [
                GeometryUtils.flip(tracked, primaryHeight: height),
                GeometryUtils.flip(other, primaryHeight: height),
            ]
        )
    }

    @Test("the list is read at a settle pass or when nothing is cached")
    func listReadCadence() {
        let core = makeCore()
        var reads = 0
        core.vision.listWindows = {
            reads += 1
            return []
        }
        core.setAppWide(persisting: false) {
            $0.visionClearWallpaper = true
        }
        core.setKiwiVision(true)
        #expect(reads == 1, "turning on is a re-stack: it reads")
        core.updateVision()
        core.updateVision()
        #expect(reads == 1, "a steady pass reads the cache")
        core.updateVision(reassertOrder: true)
        #expect(reads == 2, "a settle pass refreshes it")
        core.setAppWide(persisting: false) {
            $0.visionClearWallpaper = false
        }
        core.setAppWide(persisting: false) {
            $0.visionClearWallpaper = true
        }
        #expect(reads == 3, "a cache dropped while off is read again")
    }
}
