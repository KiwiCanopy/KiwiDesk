import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// KiwiVision's "Wallpaper" switch through a live core (#2103
/// rulings 17–21): stored app-wide as `kiwivision.clear_wallpaper`,
/// a verb a session value, and the plate masked to the windows below
/// it, front to back — the shown Spaces' members at the engine's
/// frames, every other app's window from the one cached list read.
@Suite("KiwiVision clear wallpaper")
@MainActor
struct KiwiVisionClearWallpaperTests {
    private let w1 = WindowID(1)
    private let w2 = WindowID(2)

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
        for id in [w1, w2] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: id,
                        pid: pid_t(id.raw),
                        appName: "App\(id.raw)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: w1)!
        core.state.workspaces.focus(w1, in: space)
        core.eventLoop.ownKeyWindow = { nil }
        return core
    }

    private func listed(
        _ number: CGWindowID,
        _ frame: CGRect,
        layer: Int = 0
    ) -> FloatDetection.ListedWindow {
        FloatDetection.ListedWindow(
            number: number,
            pid: 99,
            layer: layer,
            frame: frame
        )
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

    /// The list's order, the member's state frame for its slot,
    /// the target and other layers left out.
    @Test("the mask walks the list front to back")
    func maskWindowsInOrder() {
        let core = makeCore()
        let tracked = CGRect(x: 10, y: 20, width: 300, height: 200)
        core.state.windows.updateFrame(w2, frame: tracked)
        let other = CGRect(x: 500, y: 40, width: 100, height: 100)
        core.vision.listWindows = {
            [
                self.listed(99, other),
                self.listed(2, .zero),
                self.listed(1, .zero),
                self.listed(50, other, layer: -20),
            ]
        }
        let windows = core.visionMaskWindows(
            target: w1.raw,
            refreshingList: true
        )
        let height = GeometryUtils.primaryHeight
        #expect(
            windows.map(\.frame) == [
                GeometryUtils.flip(other, primaryHeight: height),
                GeometryUtils.flip(tracked, primaryHeight: height),
            ]
        )
        #expect(windows.allSatisfy { !$0.clear })
        #expect(
            windows.allSatisfy {
                $0.cornerRadius == GeometryUtils.systemWindowCornerRadius
            }
        )
    }

    /// A window tracked at the read that leaves state — another
    /// Desktop's, a closed one — is no other app's window to haze.
    @Test("a tracked window that left state is not hazed from the cache")
    func departedTrackedWindowStaysOut() {
        let core = makeCore()
        core.vision.listWindows = {
            [self.listed(2, CGRect(x: 0, y: 0, width: 50, height: 50))]
        }
        _ = core.visionMaskWindows(target: w1.raw, refreshingList: true)
        core.state.apply(.windowDestroyed(w2, wasMinimized: false))
        #expect(
            core.visionMaskWindows(target: w1.raw, refreshingList: false)
                .isEmpty
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

    /// A window that came or went owes the list a read; a tracked
    /// window that moved re-masks from state alone; another app's
    /// window that moved or hid updates the cache from its event,
    /// and its reorder re-masks rather than re-stacking the plate.
    @Test("events keep the mask fresh without a read per event")
    func eventsKeepTheMaskFresh() throws {
        let core = makeCore()
        var reads = 0
        let other = CGRect(x: 500, y: 40, width: 100, height: 100)
        core.vision.listWindows = {
            reads += 1
            return [self.listed(99, other)]
        }
        core.setAppWide(persisting: false) {
            $0.visionClearWallpaper = true
        }
        core.setKiwiVision(true)
        try #require(core.vision.hasShownPlates)
        core.noteVisionMaskEvent(.windowMoved(w2, .zero))
        #expect(!core.vision.listOwed)
        core.noteVisionMaskEvent(.appTerminated(pid: 5))
        #expect(core.vision.listOwed)
        core.reshapeVision()
        #expect(reads == 2)
        #expect(!core.vision.listOwed)
        #expect(
            core.windowServer.requested(by: .vision).contains(WindowID(99))
        )
        let moved = other.offsetBy(dx: 30, dy: 0)
        core.visionListedWindowChanged(WindowID(99), frame: moved)
        #expect(core.vision.listed?.first?.frame == moved)
        core.visionWindowRestacked(WindowID(99))
        #expect(core.vision.listOwed, "an order change re-reads, never orders")
        core.vision.listOwed = false
        core.visionListedWindowChanged(WindowID(99), frame: nil)
        #expect(core.vision.listed?.isEmpty == true)
        #expect(reads == 2)
    }
}
