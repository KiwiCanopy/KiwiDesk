import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// Pure spring model for the dead-end rubber-band
/// (`DeadEndBump`, #436). AX coordinates: y grows downward.
@Suite("Dead-end bump spring")
struct DeadEndBumpTests {
    @Test("Impulse points toward the wall in AX coords")
    func impulseDirection() {
        let a = DeadEndBump.defaultAmplitude
        #expect(
            DeadEndBump.impulse(for: .right) == CGVector(dx: a, dy: 0)
        )
        #expect(
            DeadEndBump.impulse(for: .left) == CGVector(dx: -a, dy: 0)
        )
        // Up is negative y (toward the top edge); down is positive.
        #expect(
            DeadEndBump.impulse(for: .up) == CGVector(dx: 0, dy: -a)
        )
        #expect(
            DeadEndBump.impulse(for: .down) == CGVector(dx: 0, dy: a)
        )
    }

    @Test("Amplitude clamps to the legible 1...20 pt range")
    func amplitudeClamp() {
        #expect(
            DeadEndBump.impulse(for: .right, amplitude: 1000).dx
                == DeadEndBump.maxAmplitude
        )
        #expect(
            DeadEndBump.impulse(for: .left, amplitude: 0).dx
                == -DeadEndBump.minAmplitude
        )
    }

    @Test("Bump starts at the impulse and settles back to zero")
    func settlesToRest() {
        var bump = DeadEndBump(
            offset: DeadEndBump.impulse(for: .right)
        )
        #expect(bump.offset.dx == DeadEndBump.defaultAmplitude)

        // Step ~1s at 120 Hz — well past the ~350 ms settle window.
        var settled = false
        for _ in 0..<120 where !settled {
            settled = bump.step(dt: 1.0 / 120.0)
        }
        #expect(settled)
        #expect(bump.offset == .zero)
    }

    @Test("Overshoots the wall before settling (rubber-band, not creep)")
    func overshoots() {
        var bump = DeadEndBump(
            offset: DeadEndBump.impulse(for: .right)
        )
        // The underdamped spring must cross zero (spring back past
        // the origin) at least once — a rubber-band snap, not a
        // monotone decay.
        var crossedZero = false
        for _ in 0..<120 {
            _ = bump.step(dt: 1.0 / 120.0)
            if bump.offset.dx < 0 { crossedZero = true }
        }
        #expect(crossedZero)
    }

    @Test("Reimpulse re-kicks toward the wall mid-flight")
    func reimpulseRekicks() {
        var bump = DeadEndBump(
            offset: DeadEndBump.impulse(for: .right)
        )
        for _ in 0..<10 { _ = bump.step(dt: 1.0 / 120.0) }
        let decayed = bump.offset.dx
        bump.reimpulse(offset: DeadEndBump.impulse(for: .right))
        #expect(bump.offset.dx == DeadEndBump.defaultAmplitude)
        #expect(bump.offset.dx > decayed)
    }
}
