import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

private let frameA = CGRect(x: 0, y: 0, width: 400, height: 300)
private let frameB = CGRect(
    x: 500,
    y: 200,
    width: 800,
    height: 600
)
private let frameC = CGRect(x: 100, y: 900, width: 350, height: 250)

/// Steps an animation at 120 Hz until settled (bounded).
private func settle(
    _ animation: inout FrameAnimation,
    maxSeconds: Double = 5
) -> Double {
    let dt = 1.0 / 120.0
    var elapsed = 0.0
    while elapsed < maxSeconds {
        elapsed += dt
        if animation.step(dt: dt) {
            return elapsed
        }
    }
    return elapsed
}

@Suite("Spring")
struct SpringTests {
    @Test("Scalar spring converges to its target")
    func scalarConvergence() {
        let spring = Spring()
        var position = 0.0
        var velocity = 0.0
        for _ in 0..<600 {
            spring.step(
                position: &position,
                velocity: &velocity,
                target: 100,
                dt: 1.0 / 120.0
            )
        }
        #expect(abs(position - 100) < 0.5)
        #expect(abs(velocity) < 0.5)
    }

    @Test("Frame animation settles exactly on the target")
    func frameConvergence() {
        var animation = FrameAnimation(
            from: frameA,
            to: frameB,
            spring: Spring()
        )
        let elapsed = settle(&animation)
        #expect(animation.frame == frameB)
        #expect(elapsed < 5)
    }

    @Test("Retarget keeps the current position (no jump)")
    func retargetContinuity() {
        var animation = FrameAnimation(
            from: frameA,
            to: frameB,
            spring: Spring()
        )
        for _ in 0..<12 {
            _ = animation.step(dt: 1.0 / 120.0)
        }
        let midFlight = animation.frame
        animation.retarget(to: frameC)
        #expect(animation.frame == midFlight)
        _ = settle(&animation)
        #expect(animation.frame == frameC)
    }

    @Test("Zero-distance animation settles immediately")
    func settledStart() {
        var animation = FrameAnimation(
            from: frameA,
            to: frameA,
            spring: Spring()
        )
        let settled = animation.step(dt: 1.0 / 120.0)
        #expect(settled)
    }
}

@Suite("AnimationEngine configuration")
@MainActor
struct AnimationEngineTests {
    @Test("Duration is clamped to 50-1000 ms")
    func durationClamping() {
        let engine = AnimationEngine()
        #expect(engine.durationMS == 250)
        engine.durationMS = 10
        #expect(engine.durationMS == 50)
        engine.durationMS = 5000
        #expect(engine.durationMS == 1000)
        engine.durationMS = 300
        #expect(engine.durationMS == 300)
    }
}

@Suite("AnimationEngine stepwise sizing")
@MainActor
struct AnimationEngineSizingTests {
    /// Drives an animation through the engine clock and returns
    /// every applied frame. The real display link never fires
    /// while this loop holds the main actor. Returns nil when
    /// no screen is available (headless CI).
    private func recordApplies(
        from: CGRect,
        to: CGRect,
        policy: GrowPolicy = .throttledSmooth,
        rateHz: Int? = nil
    ) -> [(frame: CGRect, setSize: Bool)]? {
        guard let screen = NSScreen.main,
            let display = screen.kiwiDisplay?.id
        else { return nil }
        let engine = AnimationEngine()
        engine.growPolicy = policy
        engine.growRateHz = rateHz
        var applies: [(frame: CGRect, setSize: Bool)] = []
        engine.apply = { _, frame, setSize in
            applies.append((frame, setSize))
        }
        engine.animate(
            window: WindowID(1),
            on: screen,
            from: from,
            to: to
        )
        var steps = 0
        while engine.activeCount > 0, steps < 2000 {
            engine.tick(display: display, dt: 1.0 / 120.0)
            steps += 1
        }
        #expect(engine.activeCount == 0)
        return applies
    }

    /// Issue #45 (`.midSlide` fallback): a growing window holds
    /// its start size, then grows in a single frame at halfway
    /// (never interpolated per tick, which would strand slow AX
    /// responders). The grow lands mid-flight — before the settle
    /// frame — so the slide masks it. This is the legacy policy
    /// kept as a Lua escape hatch; the default is smooth per-tick
    /// (below).
    @Test("A pure grow under .midSlide resizes once, mid-flight")
    func pureGrowResizesAtHalfway() throws {
        let from = CGRect(x: 10, y: 20, width: 400, height: 300)
        let to = CGRect(x: 10, y: 20, width: 900, height: 800)
        guard
            let applies = recordApplies(
                from: from,
                to: to,
                policy: .midSlide
            )
        else { return }
        #expect(applies.last?.frame == to)
        #expect(applies.last?.setSize == true)
        // The grow lands before the final settle frame.
        #expect(applies.dropLast().contains { $0.setSize })
        #expect(applies.filter(\.setSize).count <= 2)
    }

    /// #47 default: a growing window follows the spring, emitting
    /// a size-set on many frames (per-tick, since `growRateHz` is
    /// nil) instead of one at halfway — the buttery grow. It still
    /// lands exactly on the settle frame.
    @Test("A pure grow under the smooth default resizes per tick")
    func pureGrowSmoothInterpolates() throws {
        let from = CGRect(x: 10, y: 20, width: 400, height: 300)
        let to = CGRect(x: 10, y: 20, width: 900, height: 800)
        guard let applies = recordApplies(from: from, to: to)
        else { return }
        #expect(applies.last?.frame == to)
        #expect(applies.last?.setSize == true)
        // Many size-sets across the grow, not a single mid-slide
        // jump — the whole point of the smooth policy.
        #expect(applies.filter(\.setSize).count > 5)
    }

    /// A shrinking window takes its target size on the first
    /// frame — mid-flight overlap clears at once — then never
    /// resizes again until the exact settle frame.
    @Test("A pure shrink resizes on the first frame")
    func pureShrinkResizesImmediately() throws {
        let from = CGRect(x: 10, y: 20, width: 900, height: 800)
        let to = CGRect(x: 10, y: 20, width: 400, height: 300)
        guard let applies = recordApplies(from: from, to: to)
        else { return }
        #expect(applies.first?.setSize == true)
        #expect(applies.first?.frame.size == to.size)
        #expect(applies.last?.frame == to)
        #expect(applies.filter(\.setSize).count <= 2)
    }

    /// A throttle below the tick clock emits fewer size-sets than
    /// per-tick, exercising the engine's `sizeElapsed` carry-over
    /// (nil-default tests never drive it), yet still lands exact.
    @Test("A throttled grow emits fewer size-sets than per-tick")
    func throttledGrowEmitsFewer() throws {
        let from = CGRect(x: 10, y: 20, width: 400, height: 300)
        let to = CGRect(x: 10, y: 20, width: 900, height: 800)
        guard let perTick = recordApplies(from: from, to: to),
            let throttled = recordApplies(
                from: from,
                to: to,
                rateHz: 25  // well below the 120 Hz tick clock
            )
        else { return }
        let perTickSets = perTick.filter(\.setSize).count
        let throttledSets = throttled.filter(\.setSize).count
        #expect(throttledSets < perTickSets)
        #expect(throttled.last?.frame == to)  // still exact
    }

    /// #45 regression guard: retargeting mid-grow preserves the
    /// per-window held size / throttle state, and the window still
    /// lands exactly on the *new* target — never stranded by the
    /// interrupt (the failure that reverted per-tick before #47).
    @Test("A retarget mid-grow still lands on the exact new target")
    func retargetMidGrowLandsExact() throws {
        guard let screen = NSScreen.main,
            let display = screen.kiwiDisplay?.id
        else { return }
        let engine = AnimationEngine()
        var applies: [(frame: CGRect, setSize: Bool)] = []
        engine.apply = { _, frame, setSize in
            applies.append((frame, setSize))
        }
        let from = CGRect(x: 0, y: 0, width: 400, height: 300)
        let mid = CGRect(x: 0, y: 0, width: 1000, height: 900)
        engine.animate(
            window: WindowID(1),
            on: screen,
            from: from,
            to: mid
        )
        for _ in 0..<12 {
            engine.tick(display: display, dt: 1.0 / 120.0)
        }
        // Retarget: width now smaller than the grown size (snap),
        // height larger (keep growing).
        let final = CGRect(x: 0, y: 0, width: 500, height: 1100)
        engine.animate(
            window: WindowID(1),
            on: screen,
            from: mid,
            to: final
        )
        var steps = 0
        while engine.activeCount > 0, steps < 2000 {
            engine.tick(display: display, dt: 1.0 / 120.0)
            steps += 1
        }
        #expect(engine.activeCount == 0)
        #expect(applies.last?.frame == final)
        #expect(applies.last?.setSize == true)
    }
}
