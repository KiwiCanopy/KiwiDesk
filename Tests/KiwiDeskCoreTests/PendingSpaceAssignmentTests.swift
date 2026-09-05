import Foundation
import Testing

@testable import KiwiDeskCore

/// The Space an explicit Desktop-move target names, held until
/// the window departs (#1150). The record is pure — a window id,
/// a Space and a date — so every bound is asserted by passing the
/// clock in rather than by sleeping (tests.md). The DRAIN — the
/// gone handler claiming it and re-filing the departure — is
/// `DesktopMoveSpaceTargetTests`', through the real dispatch and
/// fold.
@MainActor
@Suite("A Desktop move's explicit Space is pending (#1150)")
struct PendingSpaceAssignmentTests {
    private let moved = WindowID(7)
    private let other = WindowID(9)
    private let mail = SpaceID("mail")
    private let t0 = Date(timeIntervalSince1970: 1_000)

    @Test("a recorded name is claimed once")
    func recordedNameIsClaimedOnce() {
        let ledger = PendingSpaceAssignment()
        ledger.record(moved, space: mail, at: t0)
        #expect(ledger.claim(moved, at: t0) == mail)
        #expect(ledger.claim(moved, at: t0) == nil)
        #expect(ledger.isEmpty)
    }

    /// A move the bridge accepted but never applied produces no
    /// departure; the name must not attach to a close minutes
    /// later.
    @Test("an expired name is dropped")
    func expiredNameIsDropped() {
        let ledger = PendingSpaceAssignment()
        ledger.record(moved, space: mail, at: t0)
        let late = t0.addingTimeInterval(
            PendingSpaceAssignment.drainWindow + 0.01
        )
        #expect(ledger.claim(moved, at: late) == nil)
        #expect(ledger.isEmpty)
    }

    @Test("names are per window")
    func namesArePerWindow() {
        let ledger = PendingSpaceAssignment()
        ledger.record(moved, space: mail, at: t0)
        ledger.record(other, space: SpaceID("2"), at: t0)
        #expect(ledger.claim(other, at: t0) == SpaceID("2"))
        #expect(ledger.claim(moved, at: t0) == mail)
    }

    @Test("a re-key carries the name to the new id")
    func rekeyFollows() {
        let ledger = PendingSpaceAssignment()
        ledger.record(moved, space: mail, at: t0)
        ledger.rekey(old: moved, new: other)
        #expect(ledger.claim(moved, at: t0) == nil)
        #expect(ledger.claim(other, at: t0) == mail)
    }
}
