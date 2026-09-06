import QuartzCore
import Testing

@testable import KiwiDeskCore

/// **The bars stand down under Reduce Motion** (#1078). The App
/// Bar's items slid to their new frames, its plate slid with
/// them and the Space Bar's drop ring swept its stroke, all at
/// full motion, while the border cues beside them already read
/// the setting — an inconsistency inside Core rather than a
/// deliberate line.
///
/// This holds the decisions; `BarMotionSeamTests` holds that the
/// bars still route through them, since a decision proved
/// correct in a file nothing calls gates nothing. Every decision
/// takes the flag as an argument, so none of them reads the live
/// setting and the suite needs no global to restore.
@Suite("Bar Reduce Motion decisions (#1078)")
struct BarMotionTests {
    private static let a = CGRect(x: 0, y: 0, width: 10, height: 2)
    private static let b = CGRect(x: 40, y: 0, width: 10, height: 2)

    @Test("A layout group has no duration under Reduce Motion")
    func groupCollapses() {
        #expect(BarMotion.duration(reduceMotion: true) == 0)
        #expect(BarMotion.duration(reduceMotion: false) > 0)
    }

    @Test("An item lands in its new frame, never travels to it")
    func frameLands() {
        #expect(
            !BarMotion.travels(
                true,
                from: Self.a,
                to: Self.b,
                reduceMotion: true
            )
        )
        #expect(
            BarMotion.travels(
                true,
                from: Self.a,
                to: Self.b,
                reduceMotion: false
            )
        )
    }

    /// The two refusals that predate the gate, pinned so the
    /// gate cannot be read as their only reason: a view still at
    /// `.zero` is appearing rather than moving, and a write that
    /// changes nothing has nothing to animate.
    @Test("A first layout and a no-op write never travel")
    func frameRefusals() {
        #expect(
            !BarMotion.travels(
                true,
                from: .zero,
                to: Self.b,
                reduceMotion: false
            )
        )
        #expect(
            !BarMotion.travels(
                true,
                from: Self.a,
                to: Self.a,
                reduceMotion: false
            )
        )
        #expect(
            !BarMotion.travels(
                false,
                from: Self.a,
                to: Self.b,
                reduceMotion: false
            )
        )
    }

    /// The affordance survives the gate: the ring is still there
    /// to be seen, and it still stays away for the quiet window
    /// so a flick-to-relocate flashes nothing (#372). What it
    /// loses is the countdown.
    @Test("The pending-spring ring marks instead of sweeping")
    func springRingMarks() throws {
        let mark = try #require(
            BarMotion.springSweep(
                fill: 1,
                delay: 0.5,
                reduceMotion: true
            ) as? CABasicAnimation
        )
        #expect(mark.fromValue as? Double == 0)
        #expect(mark.toValue as? Double == 0)
        #expect(mark.duration == 0.5)
        // The layer's own `strokeEnd` is 1, so the ring appears
        // whole the moment this expires — removal IS the step.
        #expect(mark.isRemovedOnCompletion)
    }

    @Test("The ring sweeps its stroke at full motion")
    func springRingSweeps() throws {
        let sweep = try #require(
            BarMotion.springSweep(
                fill: 1,
                delay: 0.5,
                reduceMotion: false
            ) as? CABasicAnimation
        )
        #expect(sweep.fromValue as? Double == 0)
        #expect(sweep.toValue as? Double == 1)
        #expect(sweep.duration == 1)
        #expect(sweep.beginTime > CACurrentMediaTime())
        #expect(sweep.fillMode == .both)
        #expect(!sweep.isRemovedOnCompletion)
    }
}
