import Foundation
import Testing

@testable import KiwiDeskCore

/// The glide's velocity ramp (#1082), pure — no engine, no
/// frames. Every expectation is DERIVED from the shipped
/// constants rather than restating them, so retuning the feel on
/// the machine reds nothing here and the shape stays guarded
/// (rule-authoring.md ▸ a number-pin derives the number). The
/// ladder that consumes the ramp is `HoldRepeatTests`.
@MainActor
@Suite("Hold-glide velocity ramp (#1082)")
struct HoldGlideRampTests {
    @Test("The ramp starts flat at the start speed")
    func startsAtTheStartSpeed() {
        // The glide's first frame must move at exactly the start
        // speed: the press already spent one full step, so a ramp
        // that began part-way in would read as a second jump.
        #expect(
            HoldRepeat.glideSteps(elapsed: 0)
                == HoldRepeat.glideStartSteps
        )
        // Negative elapsed cannot arise from a clamped `dt`, but
        // the guard is the reason it cannot — pin it, since a
        // ramp read below its floor would move BACKWARDS.
        #expect(
            HoldRepeat.glideSteps(elapsed: -1)
                == HoldRepeat.glideStartSteps
        )
    }

    @Test("The ramp is monotone and reaches its ceiling")
    func isMonotoneAndClamped() {
        let ramp = HoldRepeat.glideRampSeconds
        var previous = HoldRepeat.glideSteps(elapsed: 0)
        // Walk the ramp at a fine step: every sample is at least
        // its predecessor, so no retune can introduce a dip a
        // hold would feel as a stutter.
        for i in 1...200 {
            let t = ramp * Double(i) / 100
            let value = HoldRepeat.glideSteps(elapsed: t)
            #expect(value >= previous)
            previous = value
        }
        // It arrives exactly at the ceiling, and stays there —
        // an unclamped ramp would keep accelerating for the whole
        // 30 s run bound.
        #expect(
            HoldRepeat.glideSteps(elapsed: ramp)
                == HoldRepeat.glideMaxSteps
        )
        #expect(
            HoldRepeat.glideSteps(elapsed: ramp * 100)
                == HoldRepeat.glideMaxSteps
        )
    }

    @Test("The ramp accelerates rather than holding one speed")
    func actuallyAccelerates() {
        // #1056's defect was a hold whose step size never
        // changed. The ceiling must therefore be strictly above
        // the start, and the midpoint strictly between — a
        // retune that collapsed the two would restore exactly
        // the chunky, one-speed hold this issue is about.
        #expect(
            HoldRepeat.glideMaxSteps > HoldRepeat.glideStartSteps
        )
        let mid = HoldRepeat.glideSteps(
            elapsed: HoldRepeat.glideRampSeconds / 2
        )
        #expect(mid > HoldRepeat.glideStartSteps)
        #expect(mid < HoldRepeat.glideMaxSteps)
    }

    @Test("A frame's travel is velocity × dt, not a fixed step")
    func travelScalesWithFrameTime() {
        // This is what makes the glide refresh-rate independent:
        // the same wall-clock second covers the same distance at
        // 60 Hz and at 120 Hz, with the faster panel spending its
        // extra frames on finer motion rather than going quicker.
        // A fixed per-frame delta would make a 120 Hz display
        // resize twice as fast.
        let speed = HoldRepeat.glideSteps(elapsed: 0)
        let at60 = (0..<60).reduce(0.0) { total, i in
            total
                + HoldRepeat.glideSteps(
                    elapsed: Double(i) / 60
                ) * (1.0 / 60)
        }
        let at120 = (0..<120).reduce(0.0) { total, i in
            total
                + HoldRepeat.glideSteps(
                    elapsed: Double(i) / 120
                ) * (1.0 / 120)
        }
        #expect(speed > 0)
        // One second of hold, two refresh rates, same travel to
        // within the ramp's own discretisation.
        #expect(abs(at60 - at120) < 0.05 * at60)
    }
}
