import ApplicationServices
import CoreGraphics
import Testing
import os

@testable import KiwiDeskCore

/// The applier's recently-set stamp is written at ENQUEUE, before
/// the set is performed (#1254): an app posts its resize
/// notification while performing our set, and the echo's read
/// reached the forget gate before the post-set stamp, which
/// classified the spring's first frame as a user resize and wiped
/// the size-bound ask (the measurement is on the issue). The
/// tests read the stamp synchronously after the call, which is
/// exactly the window the echo lands in; the own-pid element
/// routes the set to the main queue, so nothing has run yet. Two
/// deliberate residues: the queued block later performs an AX set
/// (and, for the instant path, an EUI read) against the test
/// process's own application element, which fails harmlessly; and
/// stamping ahead of the element guard stamps a window whose
/// element is gone, an echo-vouch that expires unread or, for an
/// id re-elemented inside the grace (#1145), seeds one raw
/// candidate the next settled read clears.
@Suite("Frame applier stamps at enqueue (#1254)", .serialized)
@MainActor
struct FrameApplierStampTests {
    private let w = WindowID(1)

    private func makeApplier() -> FrameApplier {
        let applier = FrameApplier()
        let element = AXUIElementCreateApplication(getpid())
        applier.elementProvider = { _ in element }
        return applier
    }

    @Test("An animated frame is recent before its set runs")
    func animatedApplyIsRecentAtEnqueue() {
        let applier = makeApplier()
        #expect(!applier.didRecentlySetFrame(w))
        applier.apply(
            w,
            CGRect(x: 0, y: 0, width: 100, height: 100),
            setSize: true
        )
        #expect(applier.didRecentlySetFrame(w))
    }

    /// The grace is measured on the injected clock (#1456): a
    /// frozen clock never ages a stamp, and a clock moved past
    /// the bound expires it without a sleep — the shape a test
    /// that wants the EXPIRY takes (tests.md).
    @Test("The grace is measured on the injected clock")
    func graceRunsOnTheInjectedClock() {
        let applier = makeApplier()
        // Locked, not captured: the applier's post-set stamp reads
        // the clock on the AX queue while this test moves it.
        let now = OSAllocatedUnfairLock<TimeInterval>(initialState: 100)
        applier.clock = { now.withLock { $0 } }
        applier.applyInstant(
            w,
            CGRect(x: 0, y: 0, width: 100, height: 100)
        )
        #expect(applier.didRecentlySetFrame(w))
        #expect(applier.instantTarget(w) != nil)
        now.withLock { $0 = 100.5 }
        #expect(applier.didRecentlySetFrame(w))
        now.withLock { $0 = 101.5 }
        #expect(!applier.didRecentlySetFrame(w))
        #expect(applier.instantTarget(w) == nil)
    }

    @Test("An instant frame is recent before its set runs")
    func instantApplyIsRecentAtEnqueue() {
        let applier = makeApplier()
        #expect(!applier.didRecentlySetFrame(w))
        applier.applyInstant(
            w,
            CGRect(x: 0, y: 0, width: 100, height: 100)
        )
        #expect(applier.didRecentlySetFrame(w))
    }

    @Test("A frame for a window with no element still stamps")
    func elementlessApplyStillStamps() {
        // The stamp precedes the element guard: a set that cannot
        // be performed has no echo, and the stamp expires unread —
        // the cost of stamping early is nothing, the cost of a
        // late stamp is #1254.
        let applier = FrameApplier()
        applier.apply(
            w,
            CGRect(x: 0, y: 0, width: 100, height: 100),
            setSize: true
        )
        #expect(applier.didRecentlySetFrame(w))
    }
}
