import AppKit
import QuartzCore
import Testing

@testable import KiwiDeskCore

/// A burst of presses on the plate slide (#1956), on the overlay
/// alone with its clock pinned: a press while the strip moves
/// carries its speed on, a press after the windows landed waits
/// for their park again, and a press on another screen hands back
/// the holds of the play it drops. The panel is never ordered in.
@Suite("Plate slide bursts (#1956)", .serialized)
@MainActor
struct SpaceSlideBurstTests {
    private final class Clock {
        var now: CFTimeInterval = 100
    }

    private func makeOverlay(_ clock: Clock) -> SpaceSlideOverlay {
        let overlay = SpaceSlideOverlay()
        overlay.present = { _ in }
        overlay.reduceMotion = { false }
        overlay.clock = { clock.now }
        return overlay
    }

    private func press(
        _ overlay: SpaceSlideOverlay,
        display: DisplayID = DisplayID(1),
        holding: Set<WindowID> = []
    ) -> SpaceSlideOverlay.Pressed {
        overlay.press(
            SpaceSlideOverlay.Press(
                display: display,
                screen: CGRect(x: 0, y: 0, width: 1000, height: 800),
                axis: .horizontal,
                direction: 1,
                outgoing: [],
                holes: [],
                holding: holding,
                glass: false
            )
        )
    }

    @Test("a press mid-flight goes on at the strip's speed")
    func burstGoesOn() throws {
        let clock = Clock()
        let overlay = makeOverlay(clock)
        defer { overlay.end() }
        let first = press(overlay)
        overlay.run(incoming: [], holes: [])
        let start = try #require(overlay.play?.motion.begin)
        #expect(start == 100 + SpaceSlidePlan.stripDelay)
        clock.now = start + 0.1
        let second = press(overlay)
        let motion = try #require(overlay.play?.motion)
        #expect(motion.begin == clock.now)
        #expect(motion.velocity > 0)
        #expect(motion.to == 2000)
        #expect(second.landAt > first.landAt)
    }

    @Test("a press after the landing waits for the park again")
    func landedPressWaits() throws {
        let clock = Clock()
        let overlay = makeOverlay(clock)
        defer { overlay.end() }
        let first = press(overlay)
        overlay.run(incoming: [], holes: [])
        // Landed, but the spring still creeps toward rest.
        clock.now = first.landAt + 0.01
        _ = press(overlay)
        let motion = try #require(overlay.play?.motion)
        #expect(motion.begin == clock.now + SpaceSlidePlan.stripDelay)
        #expect(motion.velocity == 0)
    }

    @Test("the landing is solved from the motion played")
    func landingFollowsTheMotion() throws {
        let clock = Clock()
        let overlay = makeOverlay(clock)
        defer { overlay.end() }
        let first = press(overlay)
        let begin = try #require(overlay.play?.motion.begin)
        #expect(
            abs(first.landAt - begin - SpaceSlidePlan.settle) < 0.01
        )
    }

    @Test("a press on another screen hands back the dropped holds")
    func otherScreenReleases() {
        let clock = Clock()
        let overlay = makeOverlay(clock)
        defer { overlay.end() }
        let a: Set = [WindowID(1), WindowID(2)]
        let b: Set = [WindowID(3)]
        #expect(press(overlay, holding: a).released.isEmpty)
        let other = press(overlay, display: DisplayID(2), holding: b)
        #expect(other.released == a)
        #expect(overlay.end() == b)
    }

    @Test("a long burst keeps a bounded strip")
    func pagesStayBounded() throws {
        let clock = Clock()
        let overlay = makeOverlay(clock)
        defer { overlay.end() }
        for step in 0..<8 {
            clock.now = 100 + Double(step) * 0.05
            _ = press(overlay)
            overlay.run(incoming: [], holes: [])
        }
        let pages = try #require(overlay.play?.pages.count)
        #expect(pages <= 5)
    }
}
