import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

private let bounds = CGRect(
    x: 0,
    y: 25,
    width: 1920,
    height: 1055
)

private func makeWindow(
    _ id: UInt32,
    frame: CGRect = CGRect(
        x: 100,
        y: 100,
        width: 800,
        height: 600
    )
) -> ManagedWindow {
    ManagedWindow(
        id: WindowID(id),
        pid: 100,
        appName: "TestApp",
        title: "Doc",
        frame: frame
    )
}

/// The coordinated space-switch transition (#207): the exit
/// slide to the stash corner, the pending entrance retile, and
/// the guard that keeps an instant park from snapping a window
/// already sliding to the same corner.
@Suite("Coordinated space transition (#207)", .serialized)
@MainActor
struct SpaceTransitionTests {
    @Test("Animated stash starts a slide, not an instant set")
    func animatedStashSlides() {
        // The spring path needs a display link (headless CI
        // skips); the instant fallback is covered below.
        guard
            let screen = NSScreen.main,
            screen.kiwiDisplay != nil
        else { return }
        let engine = TilingEngine()
        let window = makeWindow(1)
        engine.stash(
            window,
            in: bounds,
            corner: .bottomRight,
            force: true,
            animated: true
        )
        #expect(
            engine.animation.isAnimating(window: WindowID(1))
        )
        let target = engine.animation.targetFrame(
            window: WindowID(1)
        )
        #expect(
            target
                == TilingEngine.stashFrame(
                    window.frame,
                    in: bounds,
                    corner: .bottomRight
                )
        )
        engine.animation.cancelAll()
    }

    @Test("Instant park lets a slide to the same corner finish")
    func instantStashSkipsInFlightSlide() {
        guard
            let screen = NSScreen.main,
            screen.kiwiDisplay != nil
        else { return }
        let engine = TilingEngine()
        let window = makeWindow(1)
        engine.stash(
            window,
            in: bounds,
            corner: .bottomRight,
            force: true,
            animated: true
        )
        // An event retile (or the 300 ms settle) landing
        // mid-exit re-parks instantly; it must not cancel the
        // slide and teleport the window to the corner.
        engine.stash(
            window,
            in: bounds,
            corner: .bottomRight,
            force: true
        )
        #expect(
            engine.animation.isAnimating(window: WindowID(1))
        )
        engine.animation.cancelAll()
    }

    @Test("Instant park to another corner cancels the slide")
    func instantStashRetargetsAcrossCorners() {
        guard
            let screen = NSScreen.main,
            screen.kiwiDisplay != nil
        else { return }
        let engine = TilingEngine()
        let window = makeWindow(1)
        engine.stash(
            window,
            in: bounds,
            corner: .bottomRight,
            force: true,
            animated: true
        )
        // A different target (display topology changed the
        // optimal corner) is a real re-park: the stale slide
        // must yield to the instant set.
        engine.stash(
            window,
            in: bounds,
            corner: .bottomLeft,
            force: true
        )
        #expect(
            !engine.animation.isAnimating(window: WindowID(1))
        )
    }

    @Test("targetFrame is nil for a window not animating")
    func targetFrameNilWhenIdle() {
        let engine = AnimationEngine()
        #expect(engine.targetFrame(window: WindowID(1)) == nil)
    }
}

/// The switch-level policy at the `KiwiCore` seam: one toggle
/// drives both directions of the concurrent out+in.
@Suite("Coordinated switch policy (#207)", .serialized)
@MainActor
struct SpaceSwitchPolicyTests {
    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-transition-\(UUID().uuidString)"
                )
        )
    }

    private func addWindow(_ core: KiwiCore, _ raw: UInt32) {
        core.state.apply(
            .windowCreated(makeWindow(raw))
        )
    }

    @Test("Switch with animation off starts no animations")
    func instantSwitchStartsNothing() {
        guard NSScreen.main?.kiwiDisplay != nil else { return }
        let core = makeCore()
        core.tiler.settings.animations.onSpaceChange = false
        addWindow(core, 1)
        _ = core.focusSpace([.string("2")])
        #expect(core.tiler.animation.activeCount == 0)
        #expect(
            core.state.workspaces.activeSpace == SpaceID(2)
        )
    }

    @Test("Coordinated switch animates out and in concurrently")
    func coordinatedSwitchAnimatesBothDirections() {
        guard NSScreen.main?.kiwiDisplay != nil else { return }
        let core = makeCore()
        core.tiler.settings.animations.onSpaceChange = true
        // Instant setup: window 2 moves to space 2 without
        // starting animations the assertions would trip over.
        core.tiler.animation.isEnabled = false
        addWindow(core, 1)
        addWindow(core, 2)
        core.execute("move_to_space", args: [.string("2")])
        core.tiler.animation.isEnabled = true
        _ = core.focusSpace([.string("2")])
        // Both directions in one pass: the outgoing window
        // slides to the stash corner WHILE the incoming one
        // slides to its slot — no all-parked quiet phase.
        #expect(
            core.tiler.animation.isAnimating(
                window: WindowID(1)
            )
        )
        #expect(
            core.tiler.animation.isAnimating(
                window: WindowID(2)
            )
        )
        core.tiler.animation.cancelAll()
    }
}
