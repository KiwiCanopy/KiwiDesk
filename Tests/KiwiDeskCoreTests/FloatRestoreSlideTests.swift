import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A coordinated Space switch slides a parked float back in from
/// its corner, as it slides the tiled windows (#1909, #207), and
/// a later instant pass leaves that slide to land. A slide needs
/// a display link, so a host with no screen skips. Screens pinned
/// (#531).
@Suite("Float restore slides on a switch (#1909)", .serialized)
@MainActor
struct FloatRestoreSlideTests {
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

    @Test(
        "The switch pass slides the float in",
        .enabled(if: NSScreen.main != nil)
    )
    func switchSlides() {
        let (engine, state) = makeEngine()
        engine.restoreStashed(state: state, frames: [:], animated: true)
        #expect(engine.animation.targetFrame(window: id) == original)
        #expect(engine.recentInstantTarget(id) == nil)
        engine.animation.cancelAll(snapToTargets: false)
    }

    @Test(
        "An instant pass leaves the slide to land",
        .enabled(if: NSScreen.main != nil)
    )
    func settleKeepsTheSlide() {
        let (engine, state) = makeEngine()
        engine.restoreStashed(state: state, frames: [:], animated: true)
        // The settle's pass, 300 ms on, mid-slide.
        engine.restoreStashed(state: state, frames: [:])
        #expect(engine.animation.targetFrame(window: id) == original)
        #expect(engine.recentInstantTarget(id) == nil)
        engine.animation.cancelAll(snapToTargets: false)
    }

    @Test("Every other pass delivers the float at once")
    func otherPassesSnap() {
        let (engine, state) = makeEngine()
        engine.restoreStashed(state: state, frames: [:])
        #expect(engine.animation.targetFrame(window: id) == nil)
        #expect(engine.recentInstantTarget(id) == original)
    }

    @Test(
        "The switch retile hands its animation to the restore",
        .enabled(if: NSScreen.main != nil)
    )
    func switchRetileWiresTheSlide() {
        let core = makeTestCore()
        core.tiler.applier.clock = { 0 }
        core.tiler.visibleBounds = { [screen] _ in screen }
        core.tiler.allScreenBounds = { [screen] }
        core.tiler.settings.animations.onSpaceChange = true
        core.state.apply(.windowCreated(float))
        core.tiler.stashedFrames[id] = original
        core.spaceSwitchRetile()
        #expect(core.tiler.animation.targetFrame(window: id) == original)
        core.tiler.animation.cancelAll(snapToTargets: false)
    }
}
