import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The motion gate's owed direct writes (#2627, #2628): an owed
/// placement outranks a re-anchor for the same window, and a write
/// owed while nothing is owed holds a pass of its own, so the
/// release that pays it is armed. The gate stands alone, its hand
/// and clock driven by hand.
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

    @Test("an owed placement outranks a re-anchor, whichever came first")
    func placementOutranksReanchor() {
        let first = gate(moving: true)
        first.owe(.floatPlacement, for: window)
        first.owe(.reanchor, for: window)
        #expect(first.owedWrites[window] == .floatPlacement)
        let second = gate(moving: true)
        second.owe(.reanchor, for: window)
        second.owe(.floatPlacement, for: window)
        #expect(second.owedWrites[window] == .floatPlacement)
    }

    @Test("a write owed while nothing is owed holds a pass")
    func oweAloneHoldsAPass() {
        let gate = gate(moving: true)
        #expect(gate.owed == nil)
        gate.owe(.reanchor, for: window)
        #expect(gate.owed != nil)
    }
}
