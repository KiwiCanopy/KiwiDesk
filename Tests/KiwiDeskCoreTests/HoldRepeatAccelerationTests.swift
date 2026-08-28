import Foundation
import Testing

@testable import KiwiDeskCore

/// The acceleration ramp on a held resize (#1056, owner ruling
/// 2026-08-28): system rate first, speeding up over a long
/// hold. Every clause derives from `HoldRepeat`'s own feel
/// constants rather than restating their values, so the owner
/// retuning the feel at the machine reds nothing here — the
/// SHAPE (flat start, monotone ramp, hard floor, per-press
/// reset) is what a regression would break.
@MainActor
@Suite("Hold-to-repeat acceleration (#1056)")
struct HoldRepeatAccelerationTests {
    private let base: TimeInterval = 0.1

    @Test("A short hold rides the plain system interval")
    func shortHoldStaysAtSystemRate() {
        for tick in 1...HoldRepeat.accelerationStartTick {
            #expect(
                HoldRepeat.acceleratedInterval(
                    base: base,
                    tick: tick
                ) == base
            )
        }
    }

    @Test("Past the start the interval only ever shrinks")
    func rampIsMonotone() {
        var previous = base
        for tick in 1...200 {
            let interval = HoldRepeat.acceleratedInterval(
                base: base,
                tick: tick
            )
            #expect(interval <= previous)
            #expect(interval > 0)
            previous = interval
        }
        // And it genuinely accelerated — a ramp that never
        // leaves the base rate is the ruling not implemented.
        #expect(previous < base)
    }

    @Test("The floor holds and is reached")
    func floorHoldsAndIsReached() {
        let floor = base / HoldRepeat.maxSpeedup
        for tick in 1...200 {
            #expect(
                HoldRepeat.acceleratedInterval(
                    base: base,
                    tick: tick
                ) >= floor
            )
        }
        #expect(
            HoldRepeat.acceleratedInterval(base: base, tick: 200)
                == floor
        )
    }

    /// Pins the run's tick CLOCK — that each tick advances the
    /// ramp index and a new press resets it. The ramp's own
    /// shape is `rampIsMonotone`/`floorHoldsAndIsReached`'s
    /// job: this test derives its expectations from
    /// `acceleratedInterval` itself, so a mutation of that
    /// function cannot red here (guard-prover, #1056).
    @Test("A run's scheduled delays follow the ramp")
    func runSchedulesTheRamp() {
        let engine = HoldRepeat()
        engine.releaseCapable = true
        engine.initialDelay = { 0.5 }
        engine.interval = { [base] in base }
        var delays: [TimeInterval] = []
        var pending: (() -> Void)?
        engine.schedule = { delay, work in
            delays.append(delay)
            pending = work
            return {}
        }
        engine.fire = { _ in }

        func fire(press: Bool) {
            _ = engine.beginFire()
            engine.noteCommand("resize", succeeded: true)
            engine.endFire(id: 1, press: press)
        }

        fire(press: true)
        let ticks = HoldRepeat.accelerationStartTick + 8
        for _ in 1...ticks {
            pending?()
            fire(press: false)
        }
        // Delay 0 is the initial delay; delay n is the one
        // scheduled after repeat tick n, i.e. the ramp at n.
        #expect(delays.first == 0.5)
        for (tick, delay) in delays.dropFirst().enumerated() {
            #expect(
                delay
                    == HoldRepeat.acceleratedInterval(
                        base: base,
                        tick: tick + 1
                    )
            )
        }

        // A new press starts a fresh run at the system rate —
        // acceleration never carries across holds.
        fire(press: true)
        pending?()
        delays = []
        fire(press: false)
        #expect(delays == [base])
    }

    @Test("The interval base is read once, at the arming press")
    func intervalBaseReadsOncePerRun() {
        // The ramp's base must not shift mid-hold, and the
        // system read is off the repeat hot path — a counting
        // closure discriminates where a constant one cannot
        // (re-review, #1056): a regression re-reading per tick
        // both bumps the count and schedules off 0.4.
        let engine = HoldRepeat()
        engine.releaseCapable = true
        engine.initialDelay = { 0.5 }
        var reads = 0
        engine.interval = {
            reads += 1
            return reads == 1 ? 0.1 : 0.4
        }
        var delays: [TimeInterval] = []
        var pending: (() -> Void)?
        engine.schedule = { delay, work in
            delays.append(delay)
            pending = work
            return {}
        }
        engine.fire = { _ in }

        func fire(press: Bool) {
            _ = engine.beginFire()
            engine.noteCommand("resize", succeeded: true)
            engine.endFire(id: 1, press: press)
        }

        fire(press: true)
        for _ in 1...3 {
            pending?()
            fire(press: false)
        }
        #expect(reads == 1)
        #expect(delays == [0.5, 0.1, 0.1, 0.1])
    }
}
