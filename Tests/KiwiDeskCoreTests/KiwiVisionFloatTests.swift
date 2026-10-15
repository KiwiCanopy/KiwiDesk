import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// Which floats KiwiVision veils, through a live core (#2103
/// ruling 3): the floats the float raise lifts above a TILED focus
/// — read from the one `floatsAboveFocus` both use — and none of
/// the windows the plate keeps clear or a ring would skip.
@Suite("KiwiVision float veils")
@MainActor
struct KiwiVisionFloatTests {
    private let tiled = WindowID(1)
    private let float = WindowID(2)

    private func makeCore(
        floatIsOverlay: Bool = false
    ) -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-vision-float-\(UUID().uuidString)"
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
                    isFloating: true,
                    isTransientOverlay: floatIsOverlay
                )
            )
        )
        let space = core.state.workspaces.space(of: tiled)!
        if core.state.workspaces.space(of: float) != space {
            core.state.workspaces.add(float, to: space)
        }
        core.state.workspaces.focus(tiled, in: space)
        core.eventLoop.ownKeyWindow = { nil }
        return core
    }

    @Test("a tiled focus veils the float lifted above it")
    func tiledFocusVeilsTheFloat() {
        let core = makeCore()
        core.setKiwiVision(true)
        let request = core.floatDimRequest(above: tiled)
        #expect(request.floats.map(\.id) == [float])
        #expect(request.on)
        #expect(core.floatDims.shown == [float])
    }

    @Test("a float focus veils nothing: the raise lifts nothing")
    func floatFocusVeilsNothing() {
        let core = makeCore()
        core.setKiwiVision(true)
        #expect(core.floatsAboveFocus(of: float).isEmpty)
        #expect(core.floatDimRequest(above: float).floats.isEmpty)
    }

    @Test("off, or behind an own key window, nothing is veiled")
    func offOrOwnKeyVeilsNothing() {
        let core = makeCore()
        #expect(core.floatDimRequest(above: tiled).floats.isEmpty)
        core.setKiwiVision(true)
        core.eventLoop.ownKeyWindow = {
            OwnKeyWindowReading(number: 777, isDialog: true)
        }
        core.updateVision()
        #expect(core.floatDims.shown.isEmpty)
    }

    @Test("a transient overlay stays clear, as it gets no ring")
    func overlayStaysClear() {
        let core = makeCore(floatIsOverlay: true)
        core.setKiwiVision(true)
        #expect(core.floatDimRequest(above: tiled).floats.isEmpty)
    }

    @Test("turning the mode off retires every veil and its watch")
    func offRetiresTheVeils() {
        let core = makeCore()
        core.setKiwiVision(true)
        core.setKiwiVision(false)
        #expect(core.floatDims.shown.isEmpty)
        #expect(core.floatDims.dormant.isEmpty)
        #expect(core.windowServer.requested(by: .floatDim).isEmpty)
    }

    /// A ring backend reporting an ordered-in panel.
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
        core.tiler.settings.borderStyle.unfocusedEnabled = true
        core.tiler.settings.floatingStyle.mark = false
        core.borders.backendFactory = { OrderedRing($0) }
        core.updateBorders()
        return core
    }

    @Test("the veil covers the float's ring as the ring draws it")
    func veilCoversTheRing() throws {
        let core = ringedCore()
        core.setKiwiVision(true)
        let veil = try #require(
            core.floatDimRequest(above: tiled).floats.first
        )
        let spec = try #require(core.borders.specs[float])
        let ring = BorderGeometry.compute(
            windowFrame: veil.frame,
            width: spec.width,
            cornerStyle: spec.cornerStyle,
            glowBlur: spec.glowBlur
        )
        #expect(
            veil.frame.insetBy(dx: -veil.outset, dy: -veil.outset)
                == ring.overlayFrame
        )
        core.tiler.settings.borderStyle.cornerStyle = .square
        core.updateBorders()
        #expect(
            core.floatDimRequest(above: tiled).floats.first?
                .cornerRadius == 0
        )
    }

    @Test("a front ring is chrome the veil orders above")
    func frontRingIsTheAnchor() {
        let core = ringedCore()
        core.tiler.settings.borderStyle.drawOrder = .front
        core.updateBorders()
        core.setKiwiVision(true)
        #expect(core.topmostChrome(of: float) == 4242)
        core.tiler.settings.borderStyle.drawOrder = .behind
        core.updateBorders()
        #expect(core.topmostChrome(of: float) == float.raw)
    }
}
