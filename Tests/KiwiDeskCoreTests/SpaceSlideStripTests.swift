import CoreGraphics
import QuartzCore
import Testing

@testable import KiwiDeskCore

/// The strip's spring (#1956): critically damped, so it never
/// overshoots, within 2 % of rest at `settle` — when the held
/// writes leave — and a press mid-flight carries the speed on.
@Suite("Plate slide strip spring (#1956)")
struct SpaceSlideStripTests {
    private let page: CGFloat = 1000

    @Test("the strip holds until it begins")
    func holdsBeforeBegin() {
        let strip = SpaceSlideStrip(from: 0, to: page, velocity: 0, begin: 10)
        #expect(strip.state(at: 9.9).offset == 0)
        #expect(strip.state(at: 9.9).velocity == 0)
    }

    @Test("it is within 2 % of rest at settle, and never past it")
    func settlesWithoutOvershoot() {
        let strip = SpaceSlideStrip(from: 0, to: page, velocity: 0, begin: 0)
        let landed = strip.state(at: SpaceSlidePlan.settle).offset
        #expect(abs(page - landed) <= 0.02 * page)
        for step in 1...200 {
            let t = CFTimeInterval(step) * 0.005
            #expect(strip.state(at: t).offset <= page + 0.001)
        }
    }

    @Test("a press mid-flight keeps the strip's position and speed")
    func burstKeepsVelocity() {
        let strip = SpaceSlideStrip(from: 0, to: page, velocity: 0, begin: 0)
        let at: CFTimeInterval = 0.1
        let before = strip.state(at: at)
        let next = strip.retargeted(to: 2 * page, at: at, begin: at + 0.12)
        #expect(next.begin == at)
        #expect(abs(next.from - before.offset) < 0.001)
        #expect(abs(next.velocity - before.velocity) < 0.001)
        #expect(next.velocity > 0)
        let after = next.state(at: at + 0.0001)
        #expect(abs(after.velocity - before.velocity) / before.velocity < 0.05)
    }

    @Test("a press on a resting strip waits for the planned start")
    func restingStripWaits() {
        let strip = SpaceSlideStrip(from: 0, to: page, velocity: 0, begin: 0)
        let next = strip.retargeted(to: 2 * page, at: 5, begin: 5.12)
        #expect(next.begin == 5.12)
        #expect(next.velocity == 0)
        #expect(abs(next.from - page) < 0.5)
    }

    @Test("from rest the strip lands at settle; carrying a reversal, later")
    func settleTimeFollowsTheMotion() {
        let rest = SpaceSlideStrip(from: 0, to: page, velocity: 0, begin: 0)
        #expect(abs(rest.settleTime() - SpaceSlidePlan.settle) < 0.01)
        let reversing = SpaceSlideStrip(
            from: 0,
            to: page,
            velocity: -20_000,
            begin: 0
        )
        #expect(reversing.settleTime() > rest.settleTime() + 0.02)
    }

    @Test("CA's initial velocity is a share of the distance")
    func normalizedVelocity() {
        let strip = SpaceSlideStrip(
            from: 100,
            to: 600,
            velocity: 1000,
            begin: 0
        )
        #expect(strip.normalizedVelocity == 2)
        let flat = SpaceSlideStrip(from: 5, to: 5, velocity: 1000, begin: 0)
        #expect(flat.normalizedVelocity == 0)
    }

    @Test("CA's spring is the modelled one")
    func caSpringMatches() {
        let spring = CASpringAnimation()
        spring.mass = 1
        spring.stiffness = SpaceSlideStrip.stiffness
        spring.damping = SpaceSlideStrip.damping
        // Critically damped: damping² == 4·k·m.
        let ratio =
            spring.damping
            / (2 * (spring.stiffness * spring.mass).squareRoot())
        #expect(abs(ratio - 1) < 0.0001)
    }
}
