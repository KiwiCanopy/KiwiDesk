import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The motion gate's owed direct writes (#2627, #2628): a write is
/// owed only while the gate holds and holds a pass of its own; the
/// payer tries a window's writes in precedence order, falling
/// through to the next where one writes nothing, inside a scope
/// where nothing holds. The gate stands alone, its hand and clock
/// driven by hand.
@Suite("Motion gate owed writes")
@MainActor
struct MotionGateOwedWriteTests {
    private let window = WindowID(4)

    private func gate(moving: Bool) -> MotionGate {
        let gate = MotionGate()
        gate.clock = { 100 }
        gate.schedule = { _, _ in }
        gate.onLog = { _ in }
        gate.quiescence.sinceMouseMoved = { moving ? 0.05 : 10 }
        return gate
    }

    @Test("a write is owed only while the gate holds")
    func owesOnlyWhileHolding() {
        let resting = gate(moving: false)
        #expect(!resting.owe(.reanchor, for: window))
        #expect(resting.owedWrites.isEmpty)
        let moving = gate(moving: true)
        #expect(moving.owe(.reanchor, for: window))
        #expect(moving.owedWrites[window] == [.reanchor])
    }

    @Test("a write owed while nothing is owed holds a pass")
    func oweAloneHoldsAPass() {
        let gate = gate(moving: true)
        #expect(gate.owed == nil)
        gate.owe(.reanchor, for: window)
        #expect(gate.owed != nil)
    }

    @Test("a placement paid ahead of a re-anchor drops the re-anchor")
    func placementPaysFirst() {
        let gate = gate(moving: true)
        gate.owe(.reanchor, for: window)
        gate.owe(.floatPlacement, for: window)
        var paid: [MotionGate.OwedWrite] = []
        gate.payWrites { _, write in
            paid.append(write)
            return true
        }
        #expect(paid == [.floatPlacement])
        #expect(gate.owedWrites.isEmpty)
    }

    @Test("a placement no longer due falls through to the re-anchor")
    func placementFallsThrough() {
        let gate = gate(moving: true)
        gate.owe(.floatPlacement, for: window)
        gate.owe(.reanchor, for: window)
        var paid: [MotionGate.OwedWrite] = []
        gate.payWrites { _, write in
            paid.append(write)
            return write == .reanchor
        }
        #expect(paid == [.floatPlacement, .reanchor])
    }

    /// A payment re-enters its writer, which asks the gate again:
    /// inside the payment nothing holds, so it writes.
    @Test("nothing holds while the writes are paid")
    func paymentHoldsNothing() {
        let gate = gate(moving: true)
        gate.owe(.reanchor, for: window)
        var heldInside = true
        gate.payWrites { _, _ in
            heldInside = gate.holdsNow
            return true
        }
        #expect(!heldInside)
        #expect(gate.holdsNow)
    }
}
