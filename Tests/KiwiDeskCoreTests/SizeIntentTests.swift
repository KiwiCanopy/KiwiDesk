import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// #593: a shrinking axis may follow the spring, but only on an
/// animation whose trigger vouches that nothing in the batch is
/// instantly sized. `SizeStepTests` is the `.reflow` half — and
/// the standing #45 net; this is the `.resize` half.
@Suite("Size intent")
struct SizeIntentTests {
    private let big = CGSize(width: 800, height: 600)
    private let small = CGSize(width: 400, height: 300)

    @Test(".resize lets a shrinking axis follow the spring")
    func resizeShrinkFollowsSpring() {
        let spring = CGSize(width: 700, height: 500)
        let step = SizeStep.step(
            policy: .throttledSmooth,
            intent: .resize,
            held: big,
            target: small,
            spring: spring,
            pastHalfway: false,
            rateHz: nil,
            elapsed: 0,
            dt: 1.0 / 120.0
        )
        #expect(step.size == spring)
        #expect(step.elapsed == 0)
    }

    /// The shrink honours the same throttle the grow arm does:
    /// below the interval it holds its last emitted size and
    /// accrues. Without this a two-axis resize would emit an
    /// uncapped size-set per tick per window in *both*
    /// directions, which is exactly the slow-AX reflow load
    /// `sizeRateHz` exists to bound (#47).
    @Test(".resize shrink holds below the throttle interval")
    func resizeShrinkHoldsUntilDue() {
        let dt = 1.0 / 120.0
        let step = SizeStep.step(
            policy: .throttledSmooth,
            intent: .resize,
            held: big,
            target: small,
            spring: CGSize(width: 700, height: 500),
            pastHalfway: false,
            rateHz: 25,  // 40 ms interval; one 8.3 ms tick
            elapsed: 0,
            dt: dt
        )
        #expect(step.size == big)
        #expect(step.elapsed == dt)
    }

    /// `.midSlide` is deaf to the intent by definition: its whole
    /// contract is the single mid-flight size-set, and widening
    /// the shrink direction there would break the one property
    /// the escape hatch exists to provide.
    @Test(".midSlide ignores the intent in both directions")
    func midSlideIgnoresIntent() {
        for intent in [SizeIntent.reflow, .resize] {
            let shrink = SizeStep.step(
                policy: .midSlide,
                intent: intent,
                held: big,
                target: small,
                spring: CGSize(width: 700, height: 500),
                pastHalfway: false,
                rateHz: nil,
                elapsed: 0,
                dt: 1.0 / 120.0
            )
            #expect(shrink.size == small)
            let grow = SizeStep.step(
                policy: .midSlide,
                intent: intent,
                held: small,
                target: big,
                spring: CGSize(width: 500, height: 400),
                pastHalfway: false,
                rateHz: nil,
                elapsed: 0,
                dt: 1.0 / 120.0
            )
            #expect(grow.size == small)
        }
    }

    /// A pure move reads as `target == held` on both axes, which
    /// lands in the *shrinking* arm — under `.resize` it must
    /// still emit no resize, or every slide would start costing
    /// an AX size call per tick.
    @Test(".resize still emits no resize on a pure move")
    func resizePureMoveEmitsNoResize() {
        let step = SizeStep.step(
            policy: .throttledSmooth,
            intent: .resize,
            held: big,
            target: big,
            spring: big,
            pastHalfway: false,
            rateHz: nil,
            elapsed: 0,
            dt: 1.0 / 120.0
        )
        #expect(step.size == big)
    }
}

/// The engine half: what a `.resize` animation actually applies,
/// and what an interrupt does to it.
@Suite("Size intent through the engine")
@MainActor
struct SizeIntentEngineTests {
    private static let from = CGRect(
        x: 10,
        y: 20,
        width: 900,
        height: 800
    )
    private static let to = CGRect(
        x: 10,
        y: 20,
        width: 400,
        height: 300
    )
    /// The second target, smaller again, so an interrupt is still
    /// a shrink relative to the mid-flight held size.
    private static let smaller = CGRect(
        x: 10,
        y: 20,
        width: 300,
        height: 200
    )
    private static let tick = 1.0 / 120.0

    @Test("A .resize shrink slides instead of snapping")
    func resizeShrinkSlides() throws {
        guard let applies = drive(intent: .resize) else { return }
        // Frame 1 is nowhere near the target — the whole point.
        #expect(try #require(applies.first).frame.width > 800)
        // Many size-sets across the shrink, not one, and the
        // final frame is still the exact target.
        #expect(applies.dropLast().filter(\.setSize).count > 5)
        #expect(applies.last?.frame == Self.to)
        #expect(applies.last?.setSize == true)
    }

    /// The contrast, and #45's invariant end to end: the same
    /// shrink under `.reflow` takes its target on frame 1.
    @Test("A .reflow shrink still snaps on the first frame")
    func reflowShrinkSnaps() throws {
        guard let applies = drive(intent: .reflow) else { return }
        #expect(applies.first?.setSize == true)
        #expect(applies.first?.frame.size == Self.to.size)
        #expect(applies.filter(\.setSize).count <= 2)
    }

    /// Newest intent wins. A structural retile landing mid-resize
    /// restores the snap — the case an engine-wide "we are
    /// resizing" flag would get wrong, since `animate` retargets
    /// an in-flight animation rather than replacing it.
    @Test("A .reflow interrupt restores the first-frame snap")
    func reflowInterruptRestoresSnap() throws {
        guard let first = interrupt(with: .reflow) else { return }
        #expect(first.setSize)
        #expect(first.frame.size == Self.smaller.size)
    }

    @Test("A .resize interrupt keeps the shrink sliding")
    func resizeInterruptKeepsSliding() throws {
        guard let first = interrupt(with: .resize) else { return }
        #expect(first.frame.size != Self.smaller.size)
        #expect(first.frame.width > Self.smaller.width)
    }

    // MARK: - Harness

    /// Drives one shrink to settle and returns every applied
    /// frame. Nil on a headless host (no `NSScreen.main`), which
    /// every caller treats as "skip", matching `AnimationTests`.
    private func drive(
        intent: SizeIntent
    ) -> [(frame: CGRect, setSize: Bool)]? {
        guard let screen = NSScreen.main,
            let display = screen.kiwiDisplay?.id
        else { return nil }
        let engine = AnimationEngine()
        var applies: [(frame: CGRect, setSize: Bool)] = []
        engine.apply = { _, frame, setSize in
            applies.append((frame, setSize))
        }
        engine.animate(
            window: WindowID(1),
            on: screen,
            from: Self.from,
            to: Self.to,
            sizeIntent: intent
        )
        var steps = 0
        while engine.activeCount > 0, steps < 2000 {
            engine.tick(display: display, dt: Self.tick)
            steps += 1
        }
        #expect(engine.activeCount == 0)
        return applies
    }

    /// Starts a `.resize` shrink, lets it fly for five ticks, then
    /// retargets with `intent` and returns the first frame applied
    /// afterwards. Nil on a headless host.
    private func interrupt(
        with intent: SizeIntent
    ) -> (frame: CGRect, setSize: Bool)? {
        guard let screen = NSScreen.main,
            let display = screen.kiwiDisplay?.id
        else { return nil }
        let engine = AnimationEngine()
        var applies: [(frame: CGRect, setSize: Bool)] = []
        engine.apply = { _, frame, setSize in
            applies.append((frame, setSize))
        }
        engine.animate(
            window: WindowID(1),
            on: screen,
            from: Self.from,
            to: Self.to,
            sizeIntent: .resize
        )
        for _ in 0..<5 {
            engine.tick(display: display, dt: Self.tick)
        }
        // Mid-flight: still sliding, far from either target.
        #expect((applies.last?.frame.width ?? 0) > Self.to.width)
        applies.removeAll()
        engine.animate(
            window: WindowID(1),
            on: screen,
            from: .zero,
            to: Self.smaller,
            sizeIntent: intent
        )
        engine.tick(display: display, dt: Self.tick)
        return applies.first
    }
}
