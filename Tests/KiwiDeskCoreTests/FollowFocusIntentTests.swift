import Foundation
import Testing

@testable import KiwiDeskCore

/// The focus a cross-screen follow owes the window it sent away
/// (#1007).
///
/// The record is pure — a window id and a date — so every bound
/// is asserted by passing the clock in rather than by sleeping;
/// `.claude/rules/tests.md` bars a tight wall-clock deadline, and
/// an injected `now` is not one.
///
/// The DRAIN itself is not here. Paying the debt means
/// `focusWindow` on a live AX window at a real arrival, which is
/// the machine; what this suite holds is that the record hands
/// the right window over at the right time. The production
/// wirings are `FollowFocusSeamTests`' register, and the
/// record→pay path is exercised end-to-end (through the real
/// dispatch and fold) by `DesktopFollowTests`.
@MainActor
@Suite("A followed departure owes a focus (#1007)")
struct FollowFocusIntentTests {
    private let moved = WindowID(7)
    private let other = WindowID(9)
    private let t0 = Date(timeIntervalSince1970: 1_000)

    private func payable(_: WindowID) -> Bool { true }
    private func unpayable(_: WindowID) -> Bool { false }

    @Test("a payable debt is paid, once")
    func payableDebtIsPaidOnce() {
        let intent = FollowFocusIntent()
        intent.record(moved, at: t0)
        #expect(intent.claim(at: t0, if: payable) == moved)
        #expect(intent.claim(at: t0, if: payable) == nil)
    }

    /// The reason `claim` takes a predicate at all: the reveal can
    /// arrive before the window's app has relisted it, and the
    /// first drain swallowing the debt would lose the follow
    /// outright.
    @Test("a live debt the caller cannot pay yet is kept")
    func unpayableDebtSurvives() {
        let intent = FollowFocusIntent()
        intent.record(moved, at: t0)
        #expect(intent.claim(at: t0, if: unpayable) == nil)
        #expect(intent.claim(at: t0, if: payable) == moved)
    }

    /// The other direction, and the one that keeps a follow macOS
    /// declined from firing minutes later.
    @Test("an expired debt is dropped even when payable")
    func expiredDebtIsDropped() {
        let intent = FollowFocusIntent()
        intent.record(moved, at: t0)
        let late = t0.addingTimeInterval(
            FollowFocusIntent.drainWindow + 0.01
        )
        #expect(intent.claim(at: late, if: payable) == nil)
        // Dropped, not merely refused: it must not pay on a
        // later drain that happens to arrive.
        #expect(intent.claim(at: t0, if: payable) == nil)
    }

    /// `owed` is the second instance's READ (#1207): the fold's
    /// mirror and the settle's stand-down ask whether a debt
    /// stands without paying it, and an expired one reads as
    /// absent — and is dropped, so a later drain cannot pay it.
    @Test("owed reads the live debt without paying it")
    func owedReadsWithoutPaying() {
        let intent = FollowFocusIntent()
        #expect(intent.owed(at: t0) == nil)
        intent.record(moved, at: t0)
        #expect(intent.owed(at: t0) == moved)
        #expect(intent.claim(at: t0, if: payable) == moved)
        #expect(intent.owed(at: t0) == nil)
    }

    @Test("an expired debt reads as absent and is dropped")
    func owedDropsAnExpiredDebt() {
        let intent = FollowFocusIntent()
        intent.record(moved, at: t0)
        let late = t0.addingTimeInterval(
            FollowFocusIntent.drainWindow + 0.01
        )
        #expect(intent.owed(at: late) == nil)
        #expect(intent.claim(at: t0, if: payable) == nil)
    }

    @Test("a re-keyed window keeps the debt and its clock")
    func rekeyKeepsTheDebt() {
        let intent = FollowFocusIntent()
        intent.record(moved, at: t0)
        intent.rekey(old: moved, new: other)
        // The debt now names the NEW id — the old one is dead.
        #expect(intent.claim(at: t0, if: { $0 == self.moved }) == nil)
        // The clock travels with it: a re-key must not silently
        // renew a debt that was about to expire.
        let late = t0.addingTimeInterval(
            FollowFocusIntent.drainWindow + 0.01
        )
        #expect(intent.claim(at: late, if: payable) == nil)
    }

    @Test("a re-key of another window leaves the debt alone")
    func rekeyOfAnotherWindowIsIgnored() {
        let intent = FollowFocusIntent()
        intent.record(moved, at: t0)
        intent.rekey(old: other, new: WindowID(11))
        #expect(intent.claim(at: t0, if: payable) == moved)
    }

    /// The drain is keyed to the arriving window, so an
    /// unrelated arrival inside the drain window leaves the debt
    /// standing rather than paying it to the wrong window. That
    /// keying replaced an explicit `clear()`: recording only
    /// after an accepted switch means there is no refused switch
    /// to compensate for.
    @Test("another window's arrival does not pay the debt")
    func anotherArrivalDoesNotPay() {
        let intent = FollowFocusIntent()
        intent.record(moved, at: t0)
        #expect(
            intent.claim(at: t0, if: { $0 == self.other }) == nil
        )
        #expect(
            intent.claim(at: t0, if: { $0 == self.moved })
                == moved
        )
    }
}
