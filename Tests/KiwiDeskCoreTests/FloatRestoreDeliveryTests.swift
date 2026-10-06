import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A parked float comes back in one instant set on every pass, a
/// Space switch's included: the plate slide draws the motion, so
/// the window itself never slides (#1956, retiring #1909's slide).
/// Screens pinned (#531).
@Suite("Float restore delivers at once (#1956)", .serialized)
@MainActor
struct FloatRestoreDeliveryTests {
    private let id = WindowID(1)
    private let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    private let corner = CGRect(x: 1919, y: 1032, width: 300, height: 200)
    private let original = CGRect(
        x: 400,
        y: 300,
        width: 300,
        height: 200
    )

    private var float: ManagedWindow {
        ManagedWindow(
            id: id,
            pid: 100,
            appName: "A",
            frame: corner,
            isFloating: true
        )
    }

    /// One float on the active Space, parked at the corner, with
    /// its original captured.
    private func makeEngine() -> (TilingEngine, StateCoordinator) {
        let engine = TilingEngine()
        engine.applier.clock = { 0 }
        engine.allScreenBounds = { [screen] }
        var state = StateCoordinator()
        state.apply(.windowCreated(float))
        engine.stashedFrames[id] = original
        return (engine, state)
    }

    @Test("A pass delivers the float at once")
    func otherPassesSnap() {
        let (engine, state) = makeEngine()
        engine.restoreStashed(state: state, frames: [:])
        #expect(engine.animation.targetFrame(window: id) == nil)
        #expect(engine.recentInstantTarget(id) == original)
    }

    @Test(
        "A switch delivers the float at once",
        .enabled(if: NSScreen.main != nil)
    )
    func switchDeliversAtOnce() {
        let core = makeTestCore()
        core.tiler.applier.clock = { 0 }
        core.tiler.visibleBounds = { [screen] _ in screen }
        core.tiler.allScreenBounds = { [screen] }
        core.tiler.settings.animations.onSpaceChange = true
        core.state.apply(.windowCreated(float))
        core.tiler.stashedFrames[id] = original
        core.spaceSwitchRetile(asSwitch: false)
        #expect(core.tiler.animation.targetFrame(window: id) == nil)
        #expect(core.tiler.recentInstantTarget(id) == original)
    }
}
