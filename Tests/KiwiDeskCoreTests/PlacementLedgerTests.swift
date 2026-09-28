import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The placement ledger's own clock (#1161): a placement lives
/// for the echo window, a renewal extends it, and the chain of
/// renewals ends at a ceiling measured from the PLACEMENT — so a
/// user's own repeated cmd-tab cannot extend their lockout past
/// `2 × echoWindow`, and an app that keeps reacting is still
/// bounced inside it.
@Suite("Placement ledger renewal (#1161)")
struct PlacementLedgerTests {
    private let id = WindowID(7)
    private let frame = CGRect(x: 0, y: 0, width: 10, height: 10)
    private let window = PlacementLedger.echoWindow

    /// The time the ledger reads, moved by hand.
    private final class Clock {
        var now: TimeInterval = 0
    }

    private func makeLedger() -> (PlacementLedger, Clock) {
        let clock = Clock()
        return (PlacementLedger { clock.now }, clock)
    }

    @Test("A renewal inside the window extends it")
    func renewalExtends() {
        let (fresh, clock) = makeLedger()
        var ledger = fresh
        ledger.stamp(id, target: frame)
        clock.now = window * 0.75
        ledger.renew(id)
        clock.now = window * 1.5
        #expect(ledger.recent(id) != nil)
    }

    @Test("A renewal past the placement's own window is refused")
    func renewalEndsAtTheCeiling() {
        let (fresh, clock) = makeLedger()
        var ledger = fresh
        ledger.stamp(id, target: frame)
        clock.now = window * 0.75
        ledger.renew(id)
        // Live (renewed), but the placement itself is past the
        // window: this renewal must not take.
        clock.now = window * 1.25
        ledger.renew(id)
        clock.now = window * 1.6
        #expect(ledger.recent(id) != nil)
        clock.now = window * 1.8
        #expect(ledger.recent(id) == nil)
    }

    @Test("A renewal of an expired entry is refused")
    func renewalOfExpiredIsRefused() {
        let (fresh, clock) = makeLedger()
        var ledger = fresh
        ledger.stamp(id, target: frame)
        clock.now = window * 1.1
        ledger.renew(id)
        clock.now = window * 1.2
        #expect(ledger.recent(id) == nil)
    }

    @Test("A displacement lives like a placement and is renewable")
    func displacementIsRenewable() {
        let (fresh, clock) = makeLedger()
        var ledger = fresh
        ledger.noteDisplaced(id, frame: frame)
        #expect(ledger.recentDisplacement(id))
        clock.now = window * 0.75
        ledger.renew(id)
        clock.now = window * 1.5
        #expect(ledger.recentDisplacement(id))
        clock.now = window * 1.8
        #expect(!ledger.recentDisplacement(id))
    }

    @Test("A placement carries the displacement, a renewal too")
    func placementCarriesTheDisplacement() {
        let (fresh, clock) = makeLedger()
        var ledger = fresh
        ledger.noteDisplaced(id, frame: frame)
        clock.now = window * 0.5
        ledger.stamp(id, target: frame)
        #expect(ledger.recentDisplacement(id))
        // The displacement ages on its own clock: an UNBROKEN
        // chain of placements — each inside the previous entry's
        // window, so nothing prunes — carries it, and only the
        // ceiling refuses it at the end (guard-prover, 2026-09-05:
        // a chain with a gap passed on the prune instead).
        clock.now = window * 1.4
        ledger.stamp(id, target: frame)
        clock.now = window * 1.9
        #expect(ledger.recentDisplacement(id))
        clock.now = window * 2.05
        #expect(!ledger.recentDisplacement(id))
    }

    @Test("A new placement restarts the ceiling")
    func stampRestartsTheCeiling() {
        let (fresh, clock) = makeLedger()
        var ledger = fresh
        ledger.stamp(id, target: frame)
        let t1 = window * 1.5
        clock.now = t1
        ledger.stamp(id, target: frame)
        clock.now = t1 + window * 0.5
        ledger.renew(id)
        clock.now = t1 + window * 1.4
        #expect(ledger.recent(id) != nil)
    }

    @Test("forgetAll empties the ledger and keeps its clock")
    func forgetAllKeepsTheClock() {
        let (fresh, clock) = makeLedger()
        var ledger = fresh
        ledger.stamp(id, target: frame)
        ledger.forgetAll()
        #expect(ledger.recent(id) == nil)
        clock.now = 42
        #expect(ledger.clock() == 42)
    }
}
