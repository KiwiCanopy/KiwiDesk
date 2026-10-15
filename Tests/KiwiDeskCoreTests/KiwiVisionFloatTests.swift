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

    @Test("turning the mode off puts every veil to sleep")
    func offSleepsTheVeils() {
        let core = makeCore()
        core.setKiwiVision(true)
        core.setKiwiVision(false)
        #expect(core.floatDims.shown.isEmpty)
        #expect(core.floatDims.dormant == [float])
        #expect(!core.floatDims.hasShown)
    }
}
