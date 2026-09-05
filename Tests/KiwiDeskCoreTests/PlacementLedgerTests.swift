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

    @Test("A renewal inside the window extends it")
    func renewalExtends() {
        var ledger = PlacementLedger()
        let t0 = Date()
        ledger.stamp(id, target: frame, at: t0)
        ledger.renew(id, at: t0.addingTimeInterval(window * 0.75))
        #expect(
            ledger.recent(id, at: t0.addingTimeInterval(window * 1.5))
                != nil
        )
    }

    @Test("A renewal past the placement's own window is refused")
    func renewalEndsAtTheCeiling() {
        var ledger = PlacementLedger()
        let t0 = Date()
        ledger.stamp(id, target: frame, at: t0)
        ledger.renew(id, at: t0.addingTimeInterval(window * 0.75))
        // Live (renewed), but the placement itself is past the
        // window: this renewal must not take.
        ledger.renew(id, at: t0.addingTimeInterval(window * 1.25))
        #expect(
            ledger.recent(id, at: t0.addingTimeInterval(window * 1.6))
                != nil
        )
        #expect(
            ledger.recent(id, at: t0.addingTimeInterval(window * 1.8))
                == nil
        )
    }

    @Test("A renewal of an expired entry is refused")
    func renewalOfExpiredIsRefused() {
        var ledger = PlacementLedger()
        let t0 = Date()
        ledger.stamp(id, target: frame, at: t0)
        ledger.renew(id, at: t0.addingTimeInterval(window * 1.1))
        #expect(
            ledger.recent(id, at: t0.addingTimeInterval(window * 1.2))
                == nil
        )
    }

    @Test("A new placement restarts the ceiling")
    func stampRestartsTheCeiling() {
        var ledger = PlacementLedger()
        let t0 = Date()
        ledger.stamp(id, target: frame, at: t0)
        let t1 = t0.addingTimeInterval(window * 1.5)
        ledger.stamp(id, target: frame, at: t1)
        ledger.renew(id, at: t1.addingTimeInterval(window * 0.5))
        #expect(
            ledger.recent(id, at: t1.addingTimeInterval(window * 1.4))
                != nil
        )
    }
}
