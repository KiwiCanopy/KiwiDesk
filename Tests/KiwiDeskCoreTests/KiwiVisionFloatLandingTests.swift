import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A float the raise lands directly under the focused window sits
/// above its ring and the plate (#2284), so it stays bright until
/// the target's overlays re-stack. While KiwiVision is on, the
/// plate hears the float tier, and a float's own reorder event —
/// its landing — re-stacks them at once (#2103).
@Suite("KiwiVision float landing")
@MainActor
struct KiwiVisionFloatLandingTests {
    private let tiled = WindowID(1)
    private let float = WindowID(2)

    private func makeCore() -> (KiwiCore, InertVisionPlate) {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-vision-landing-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: tiled, pid: 1, appName: "Tiled")
            )
        )
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: float,
                    pid: 2,
                    appName: "Float",
                    frame: CGRect(x: 300, y: 200, width: 400, height: 300),
                    isFloating: true
                )
            )
        )
        let space = core.state.workspaces.space(of: tiled)!
        if core.state.workspaces.space(of: float) != space {
            core.state.workspaces.add(float, to: space)
        }
        core.state.workspaces.focus(tiled, in: space)
        core.eventLoop.ownKeyWindow = { nil }
        core.windowServer.override = { _ in true }
        let plate = InertVisionPlate()
        core.vision.plateFactory = { plate }
        return (core, plate)
    }

    /// A ring backend reporting an ordered-in panel and counting
    /// its orders.
    private final class CountingRing: BorderOverlayBackend {
        let orderMode: BorderGeometry.Order
        var orders = 0
        init(_ order: BorderGeometry.Order) { orderMode = order }
        var orderedPanelNumber: CGWindowID? { 4242 }
        func update(
            geometry: BorderGeometry,
            colorHex: String,
            screen: NSScreen?,
            room: CGRect?
        ) {}
        func order(relativeTo windowNumber: CGWindowID) { orders += 1 }
        func hide() {}
    }

    @Test("a float's landing re-stacks the ring and the plate at once")
    func floatLandingRestacksThePlate() {
        let (core, plate) = makeCore()
        var rings: [CountingRing] = []
        core.borders.backendFactory = {
            let ring = CountingRing($0)
            rings.append(ring)
            return ring
        }
        core.updateBorders()
        core.setKiwiVision(true)
        #expect(core.windowServer.requested(by: .vision).contains(float))
        let platesBefore = plate.orders.count
        let ringsBefore = rings.map(\.orders).reduce(0, +)
        core.windowServer.handle(.reorder, window: float)
        #expect(plate.orders.count == platesBefore + 1)
        #expect(plate.orders.last == 4242)
        #expect(rings.map(\.orders).reduce(0, +) == ringsBefore + 1)
    }

    @Test("off, the plate hears no float")
    func offHearsNoFloat() {
        let (core, _) = makeCore()
        core.setKiwiVision(true)
        core.setKiwiVision(false)
        #expect(core.windowServer.requested(by: .vision).isEmpty)
    }

    /// Every plate stood down — fullscreen, a presentation — a
    /// landing re-stacks nothing: it would order the ring alone.
    @Test("a stood-down plate takes no landing restack")
    func standDownTakesNoRestack() {
        let (core, plate) = makeCore()
        var rings: [CountingRing] = []
        core.borders.backendFactory = {
            let ring = CountingRing($0)
            rings.append(ring)
            return ring
        }
        core.updateBorders()
        core.setKiwiVision(true)
        let displays = Set(core.visionRequest().screens.map(\.display))
        core.noteVisionStandDown(displays)
        #expect(!core.vision.hasShownPlates)
        let before = plate.orders.count
        let ringsBefore = rings.map(\.orders).reduce(0, +)
        core.visionWindowRestacked(float)
        #expect(plate.orders.count == before)
        #expect(rings.map(\.orders).reduce(0, +) == ringsBefore)
        #expect(core.windowServer.requested(by: .vision).contains(float))
    }
}
