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

    @Test("a float's landing re-stacks the plate over it at once")
    func floatLandingRestacksThePlate() {
        let (core, plate) = makeCore()
        core.setKiwiVision(true)
        #expect(core.windowServer.requested(by: .vision).contains(float))
        let before = plate.orders.count
        core.windowServer.handle(.reorder, window: float)
        #expect(plate.orders.count == before + 1)
        #expect(plate.orders.last == tiled.raw)
    }

    @Test("off, the plate hears no float")
    func offHearsNoFloat() {
        let (core, plate) = makeCore()
        core.setKiwiVision(true)
        core.setKiwiVision(false)
        #expect(core.windowServer.requested(by: .vision).isEmpty)
        let before = plate.orders.count
        core.visionWindowRestacked(float)
        #expect(plate.orders.count == before)
    }
}
