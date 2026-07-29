import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// #593: a shrinking axis may follow the spring, but only on an
/// animation whose trigger vouches that nothing in the batch is
/// instantly sized. `SizeStepTests` is the `.mayInstantSize` half — and
/// the standing #45 net; this is the `.allSpringSized` half.
@Suite("Batch sizing")
struct BatchSizingTests {
    private let big = CGSize(width: 800, height: 600)
    private let small = CGSize(width: 400, height: 300)

    @Test(".allSpringSized lets a shrinking axis follow the spring")
    func resizeShrinkFollowsSpring() {
        let spring = CGSize(width: 700, height: 500)
        let step = SizeStep.step(
            policy: .throttledSmooth,
            sizing: .allSpringSized,
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
    @Test(".allSpringSized shrink holds below the throttle interval")
    func resizeShrinkHoldsUntilDue() {
        let dt = 1.0 / 120.0
        let step = SizeStep.step(
            policy: .throttledSmooth,
            sizing: .allSpringSized,
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
        for sizing in [BatchSizing.mayInstantSize, .allSpringSized] {
            let shrink = SizeStep.step(
                policy: .midSlide,
                sizing: sizing,
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
                sizing: sizing,
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

}

/// The engine half: what a `.allSpringSized` animation actually applies,
/// and what an interrupt does to it.
@Suite("Batch sizing through the engine")
@MainActor
struct BatchSizingEngineTests {
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

    @Test("A .allSpringSized shrink slides instead of snapping")
    func resizeShrinkSlides() throws {
        guard let applies = drive(sizing: .allSpringSized) else { return }
        // Frame 1 is nowhere near the target — the whole point.
        #expect(try #require(applies.first).frame.width > 800)
        // Many size-sets across the shrink, not one, and the
        // final frame is still the exact target.
        #expect(applies.dropLast().filter(\.setSize).count > 5)
        #expect(applies.last?.frame == Self.to)
        #expect(applies.last?.setSize == true)
    }

    /// The contrast, and #45's invariant end to end: the same
    /// shrink under `.mayInstantSize` takes its target on frame 1.
    @Test("A .mayInstantSize shrink still snaps on the first frame")
    func reflowShrinkSnaps() throws {
        guard let applies = drive(sizing: .mayInstantSize) else { return }
        #expect(applies.first?.setSize == true)
        #expect(applies.first?.frame.size == Self.to.size)
        #expect(applies.filter(\.setSize).count <= 2)
    }

    /// Newest intent wins. A structural retile landing mid-resize
    /// restores the snap — the case an engine-wide "we are
    /// resizing" flag would get wrong, since `animate` retargets
    /// an in-flight animation rather than replacing it.
    @Test("A .mayInstantSize interrupt restores the first-frame snap")
    func reflowInterruptRestoresSnap() throws {
        guard let first = interrupt(from: .allSpringSized, to: .mayInstantSize)
        else { return }
        #expect(first.setSize)
        #expect(first.frame.size == Self.smaller.size)
    }

    @Test("A .allSpringSized interrupt keeps the shrink sliding")
    func resizeInterruptKeepsSliding() throws {
        guard
            let first = interrupt(from: .allSpringSized, to: .allSpringSized)
        else { return }
        #expect(first.frame.size != Self.smaller.size)
        #expect(first.frame.width > Self.smaller.width)
    }

    /// The dangerous ordering, and the one that shipped broken.
    ///
    /// A `.mayInstantSize` shrink renders its TARGET from frame 1
    /// while the size springs keep travelling down from the start
    /// size, so mid-flight the spring is up to the whole shrink
    /// delta above what is on screen. `.allSpringSized` reads that spring
    /// as the on-screen size — so without the re-seat in
    /// `animate`, the first frame after the interrupt jumped the
    /// window back UP by that divergence (measured at +171 pt).
    ///
    /// When the interrupted flight is a make-room shrink, that
    /// rebound re-overlaps the newcomer `animate(isNewWindow:)`
    /// already painted at full size — #45 across batches. So the
    /// load-bearing assertion is the one-way one: a shrink never
    /// grows.
    @Test("A .allSpringSized interrupt never rebounds a structural shrink")
    func resizeInterruptNeverRebounds() throws {
        guard
            let first = interrupt(from: .mayInstantSize, to: .allSpringSized)
        else { return }
        // On screen at `to` (snapped frame 1); heading for
        // `smaller`. Anything above `to` is the rebound.
        #expect(first.frame.width <= Self.to.width)
        #expect(first.frame.width >= Self.smaller.width)
    }

    /// A pure move is `target == held` on both axes, so it lands
    /// in the SHRINKING arm — and under `.allSpringSized` that arm returns
    /// the spring, not the target. The claim that this still costs
    /// no resize rests on the spring sitting exactly on its target
    /// with zero velocity, which is a fact about `Spring`, not
    /// about `smoothAxis`. Asserted through the real engine for
    /// that reason: handing `spring: big` to the pure function
    /// only restates the branch and would survive the spring
    /// itself breaking (found in review).
    @Test(".allSpringSized emits no resize on a pure move")
    func resizePureMoveEmitsNoResize() throws {
        let moved = Self.from.offsetBy(dx: 400, dy: 0)
        guard
            let applies = drive(
                from: Self.from,
                to: moved,
                sizing: .allSpringSized
            )
        else { return }
        #expect(applies.count > 5)
        #expect(applies.dropLast().allSatisfy { !$0.setSize })
    }

    /// The engine's own contract — "consecutive duplicates are
    /// skipped: sub-pixel deltas don't render but each one would
    /// still cost a blocking AX round-trip" — has to survive
    /// `.allSpringSized`. It did not: the spring hands back a fresh
    /// sub-pixel size every tick, so comparing UNROUNDED sizes
    /// marked the whole convergence tail as a resize — 13 of 36
    /// frames byte-identical to their predecessor, each one a
    /// forced content reflow on a slow-AX app (found in review).
    @Test("A .allSpringSized shrink never re-sets an unchanged frame")
    func resizeSkipsDuplicateFrames() throws {
        guard let applies = drive(sizing: .allSpringSized) else { return }
        // The settle frame is excluded: it carries the exact
        // unrounded target and is legitimately a size-set.
        let body = Array(applies.dropLast())
        let duplicates = zip(body, body.dropFirst()).filter {
            $0.frame == $1.frame && $1.setSize
        }
        #expect(duplicates.isEmpty)
    }

    // MARK: - Harness

    /// Drives one animation to settle and returns every applied
    /// frame. Nil on a headless host (no `NSScreen.main`), which
    /// every caller treats as "skip", matching `AnimationTests`.
    private func drive(
        from: CGRect? = nil,
        to: CGRect? = nil,
        sizing: BatchSizing
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
            from: from ?? Self.from,
            to: to ?? Self.to,
            sizing: sizing
        )
        var steps = 0
        while engine.activeCount > 0, steps < 2000 {
            engine.tick(display: display, dt: Self.tick)
            steps += 1
        }
        #expect(engine.activeCount == 0)
        return applies
    }

    /// Starts a shrink under `from`, lets it fly for five ticks,
    /// then retargets under `to` and returns the first frame
    /// applied afterwards. Nil on a headless host.
    private func interrupt(
        from: BatchSizing,
        to sizing: BatchSizing
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
            sizing: from
        )
        for _ in 0..<5 {
            engine.tick(display: display, dt: Self.tick)
        }
        // The first flight must still be airborne, or all three
        // interrupt tests silently exercise the *construction*
        // branch instead of the retarget one and assert nothing
        // about interrupts at all (found in review).
        #expect(engine.isAnimating(window: WindowID(1)))
        applies.removeAll()
        // A real `from` frame, not `.zero`: the retarget branch
        // ignores it, but if that path ever regressed to the
        // construction branch, `.zero` fails `isRenderable`, the
        // animation is cancelled, `applies.first` is nil and every
        // caller's headless guard swallows the regression in
        // silence (found in review).
        engine.animate(
            window: WindowID(1),
            on: screen,
            from: Self.from,
            to: Self.smaller,
            sizing: sizing
        )
        engine.tick(display: display, dt: Self.tick)
        return applies.first
    }
}
