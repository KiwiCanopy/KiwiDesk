import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// Pure size-channel policy math for the grow experiment (#47).
@Suite("GrowSize")
struct GrowSizeTests {
    private let held = CGSize(width: 400, height: 300)
    private let target = CGSize(width: 800, height: 600)

    // MARK: - midSlide (shipping default)

    @Test("midSlide holds a growing axis until halfway")
    func midSlideHoldsBeforeHalfway() {
        let step = GrowSize.step(
            policy: .midSlide,
            held: held,
            target: target,
            spring: CGSize(width: 600, height: 450),
            pastHalfway: false,
            rateHz: 25,
            elapsed: 0,
            dt: 1.0 / 120.0
        )
        #expect(step.size == held)
    }

    @Test("midSlide grows in one frame past halfway")
    func midSlideGrowsPastHalfway() {
        let step = GrowSize.step(
            policy: .midSlide,
            held: held,
            target: target,
            spring: CGSize(width: 600, height: 450),
            pastHalfway: true,
            rateHz: 25,
            elapsed: 0,
            dt: 1.0 / 120.0
        )
        #expect(step.size == target)
    }

    @Test("A shrinking axis snaps to target immediately")
    func shrinkSnapsImmediately() {
        // held larger than target on both axes → shrink.
        for policy in [GrowPolicy.midSlide, .throttledSmooth] {
            let step = GrowSize.step(
                policy: policy,
                held: target,
                target: held,
                spring: CGSize(width: 700, height: 500),
                pastHalfway: false,
                rateHz: 25,
                elapsed: 0,
                dt: 1.0 / 120.0
            )
            #expect(step.size == held)
        }
    }

    // MARK: - throttledSmooth (#47)

    @Test("A nil rate is per-tick: grow follows the spring each tick")
    func perTickFollowsSpringEveryTick() {
        let spring = CGSize(width: 612, height: 458)
        let step = GrowSize.step(
            policy: .throttledSmooth,
            held: held,
            target: target,
            spring: spring,
            pastHalfway: false,
            rateHz: nil,  // per-tick default
            elapsed: 0,
            dt: 1.0 / 120.0
        )
        #expect(step.size == spring)
        #expect(step.elapsed == 0)
    }

    @Test("Below the interval a growing axis holds and accrues")
    func throttleHoldsUntilDue() {
        let dt = 1.0 / 120.0
        let step = GrowSize.step(
            policy: .throttledSmooth,
            held: held,
            target: target,
            spring: CGSize(width: 600, height: 450),
            pastHalfway: false,
            rateHz: 25,  // interval 40 ms; one 8.3 ms tick < that
            elapsed: 0,
            dt: dt
        )
        #expect(step.size == held)
        #expect(step.elapsed == dt)
    }

    @Test("At the interval it resamples the spring and resets")
    func throttleEmitsWhenDue() {
        let spring = CGSize(width: 640, height: 470)
        let step = GrowSize.step(
            policy: .throttledSmooth,
            held: held,
            target: target,
            spring: spring,
            pastHalfway: false,
            rateHz: 25,  // interval 40 ms
            elapsed: 0.039,  // + a 8.3 ms tick crosses 40 ms
            dt: 1.0 / 120.0
        )
        #expect(step.size == spring)
        #expect(step.elapsed == 0)
    }

    @Test("A higher rate emits sooner (30 Hz vs 25 Hz band)")
    func higherRateEmitsSooner() {
        // 30 ms accrued, one 8.3 ms tick → 38.3 ms.
        // 30 Hz interval is 33.3 ms (due); 25 Hz is 40 ms (not).
        let args: (Int, Bool) -> Void = { hz, shouldEmit in
            let step = GrowSize.step(
                policy: .throttledSmooth,
                held: held,
                target: target,
                spring: CGSize(width: 640, height: 470),
                pastHalfway: false,
                rateHz: hz,
                elapsed: 0.030,
                dt: 1.0 / 120.0
            )
            #expect((step.size != held) == shouldEmit)
        }
        args(30, true)
        args(25, false)
    }
}

/// The promoted #47 default and its rate clamp.
@MainActor
@Suite("Grow policy defaults")
struct GrowDefaultsTests {
    @Test("Engine ships smooth per-tick")
    func shipsSmoothPerTick() {
        let engine = AnimationEngine()
        #expect(engine.growPolicy == .throttledSmooth)
        #expect(engine.growRateHz == nil)
    }

    @Test("Rate clamps to 1…120; nil is per-tick")
    func rateClamp() {
        let engine = AnimationEngine()
        engine.growRateHz = 500
        #expect(engine.growRateHz == 120)
        engine.growRateHz = -5
        #expect(engine.growRateHz == 1)
        engine.growRateHz = nil
        #expect(engine.growRateHz == nil)
    }
}

/// The strand detector's landed-vs-off comparison (#47 net).
@Suite("StrandDetector.landed")
struct StrandDetectorTests {
    private let target = CGRect(x: 100, y: 200, width: 800, height: 600)

    @Test("An exact / within-tolerance frame counts as landed")
    func withinToleranceLands() {
        #expect(StrandDetector.landed(target, on: target, within: 2))
        let nudged = target.offsetBy(dx: 1.5, dy: -1.5)
        #expect(StrandDetector.landed(nudged, on: target, within: 2))
    }

    @Test("An off-target edge counts as a strand")
    func offTargetStrands() {
        // App clamped the height short of the target.
        let short = CGRect(x: 100, y: 200, width: 800, height: 540)
        #expect(!StrandDetector.landed(short, on: target, within: 2))
        let moved = target.offsetBy(dx: 30, dy: 0)
        #expect(!StrandDetector.landed(moved, on: target, within: 2))
    }
}
