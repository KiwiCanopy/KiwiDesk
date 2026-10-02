import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A coordinated Space switch slides a parked float back in from
/// its corner, as it slides the tiled windows (#1909, #207), and
/// a later instant pass leaves that slide to land. The slides
/// need a display link, so a host without one skips.
@Suite("Float restore slides on a switch (#1909)", .serialized)
@MainActor
struct FloatRestoreSlideTests {
    private let id = WindowID(1)
    private let corner = CGRect(x: 1919, y: 1032, width: 300, height: 200)
    private let original = CGRect(x: 10, y: 40, width: 300, height: 200)

    /// One float on the active Space, parked at the corner, with
    /// its original captured.
    private func makeEngine() -> (TilingEngine, StateCoordinator) {
        let engine = TilingEngine()
        engine.applier.clock = { 0 }
        var state = StateCoordinator()
        state.apply(
            .windowCreated(
                ManagedWindow(
                    id: id,
                    pid: 100,
                    appName: "A",
                    frame: corner,
                    isFloating: true
                )
            )
        )
        engine.stashedFrames[id] = original
        return (engine, state)
    }

    private var hasDisplayLink: Bool {
        NSScreen.main?.kiwiDisplay != nil
    }

    @Test("The switch pass slides the float in")
    func switchSlides() {
        guard hasDisplayLink else { return }
        let (engine, state) = makeEngine()
        engine.restoreStashed(state: state, frames: [:], animated: true)
        #expect(engine.animation.targetFrame(window: id) == original)
        #expect(engine.recentInstantTarget(id) == nil)
        engine.animation.cancelAll(snapToTargets: false)
    }

    @Test("An instant pass leaves the slide to land")
    func settleKeepsTheSlide() {
        guard hasDisplayLink else { return }
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
}
