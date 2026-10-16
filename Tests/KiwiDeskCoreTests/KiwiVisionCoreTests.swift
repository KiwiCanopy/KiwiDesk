import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// KiwiVision through a live core (#2103): the verb toggles it,
/// the plates keep the focus anchor clear — or an own key window
/// that is not it, as the ring stands down for one (#933) — and
/// the target's WindowServer reorder event re-stacks them.
@Suite("KiwiVision core wiring")
@MainActor
struct KiwiVisionCoreTests {
    private let w1 = WindowID(1)
    private let w2 = WindowID(2)

    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-vision-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        for id: UInt32 in 1...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(id),
                        pid: pid_t(id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: w1)!
        core.state.workspaces.focus(w1, in: space)
        core.eventLoop.ownKeyWindow = { nil }
        return core
    }

    @Test("the verb toggles the mode and the GUI hears it")
    func verbToggles() {
        let core = makeCore()
        var heard: [Bool] = []
        core.vision.onChange = { heard.append($0) }
        let on = core.execute("kiwivision.toggle")
        #expect(on.isSuccess)
        #expect(core.kiwiVisionIsOn)
        _ = core.execute("kiwivision.toggle")
        #expect(!core.kiwiVisionIsOn)
        #expect(heard == [true, false])
    }

    /// A ring backend reporting an ordered-in panel, so
    /// `ringPanel(of:)` answers in a test core.
    private final class OrderedRing: BorderOverlayBackend {
        let orderMode: BorderGeometry.Order
        init(_ order: BorderGeometry.Order) { orderMode = order }
        var orderedPanelNumber: CGWindowID? { 4242 }
        func update(
            geometry: BorderGeometry,
            colorHex: String,
            screen: NSScreen?,
            room: CGRect?
        ) {}
        func order(relativeTo windowNumber: CGWindowID) {}
        func hide() {}
    }

    private func ringedCore() -> KiwiCore {
        let core = makeCore()
        core.borders.backendFactory = { OrderedRing($0) }
        core.updateBorders()
        return core
    }

    @Test("the plate stacks under the anchor's behind ring")
    func anchorRingIsBelow() {
        let core = ringedCore()
        let request = core.visionRequest()
        #expect(request.target == w1.raw)
        #expect(request.below == 4242)
        #expect(request.dim == 0.6)
    }

    @Test("a front ring sits above its window, so the plate takes it")
    func frontRingIsNotBelow() {
        let core = ringedCore()
        core.tiler.settings.borderStyle.drawOrder = .front
        core.updateBorders()
        #expect(core.visionRequest().below == nil)
    }

    @Test("an own key window that is not the anchor stays clear")
    func ownKeyWindowIsTheTarget() {
        let core = ringedCore()
        core.eventLoop.ownKeyWindow = {
            OwnKeyWindowReading(number: 999_999, isDialog: false)
        }
        #expect(core.visionRequest().target == 999_999)
        #expect(core.visionRequest().below == nil)
    }

    @Test("the anchor as own key window keeps its ring below")
    func anchorAsOwnKeyWindow() {
        let core = ringedCore()
        core.eventLoop.ownKeyWindow = { [w1] in
            OwnKeyWindowReading(number: Int(w1.raw), isDialog: false)
        }
        #expect(core.visionRequest().target == w1.raw)
        #expect(core.visionRequest().below == 4242)
    }

    @Test("the target is watched with borders off, and its event tees")
    func targetWatchedWithoutRings() {
        let core = makeCore()
        core.tiler.settings.borderStyle.enabled = false
        let plate = InertVisionPlate()
        core.vision.plateFactory = { plate }
        // The request sent to the WindowServer, read at its seam.
        var watched: Set<WindowID> = []
        core.windowServer.override = {
            watched = $0
            return true
        }
        core.vision.active = .plain
        core.updateBorders()
        #expect(watched == [w1])
        #expect(core.borders.overlays.isEmpty)
        #expect(core.windowServer.requested(by: .vision) == [w1])
        // The watch's own fan-out reaches the plate.
        core.vision.sync(
            VisionManager.Request(
                screens: [
                    (DisplayID(1), CGRect(x: 0, y: 0, width: 9, height: 9))
                ],
                target: w1.raw,
                below: nil,
                standDown: [],
                tracked: true,
                dim: 0.4,
                blur: false,
                clearWallpaper: false,
                windows: []
            ),
            reassert: false
        )
        let before = plate.orders.count
        core.windowServer.handle(.reorder, window: w1)
        #expect(plate.orders.count == before + 1)
        core.vision.active = .off
        core.updateBorders()
        #expect(core.windowServer.requested(by: .vision).isEmpty)
    }

    @Test("the target's restack re-stacks the plates under it")
    func restackReorders() {
        let core = makeCore()
        let plate = InertVisionPlate()
        core.vision.plateFactory = { plate }
        core.vision.active = .plain
        core.vision.sync(
            VisionManager.Request(
                screens: [
                    (DisplayID(1), CGRect(x: 0, y: 0, width: 9, height: 9))
                ],
                target: w1.raw,
                below: nil,
                standDown: [],
                tracked: true,
                dim: 0.4,
                blur: false,
                clearWallpaper: false,
                windows: []
            ),
            reassert: false
        )
        core.visionWindowRestacked(w2)
        #expect(plate.orders == [w1.raw])
        core.visionWindowRestacked(w1)
        #expect(plate.orders == [w1.raw, w1.raw])
    }

    @Test("updateBorders re-draws the plates for the anchor")
    func bordersDriveTheVision() {
        let core = makeCore()
        core.vision.active = .plain
        core.updateBorders()
        #expect(core.vision.target == w1.raw)
    }

    @Test("the shelf's verdict reaches the plates")
    func standDownComesFromTheShelf() {
        let core = makeCore()
        core.vision.active = .plain
        core.noteVisionStandDown([DisplayID(77)])
        #expect(core.visionRequest().standDown == [DisplayID(77)])
    }

    @Test("stopping the core turns KiwiVision off, unannounced")
    func stopClears() {
        let core = makeCore()
        var heard: [Bool] = []
        core.vision.onChange = { heard.append($0) }
        core.vision.active = .plain
        core.stop()
        #expect(!core.kiwiVisionIsOn)
        #expect(heard.isEmpty)
    }
}
