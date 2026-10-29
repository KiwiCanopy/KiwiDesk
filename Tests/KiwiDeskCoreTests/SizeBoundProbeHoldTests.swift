import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The hold's bookkeeping (#2758): which layout frame an issued,
/// unanswered corroboration probe holds back, and what ends the
/// hold. The device's shape: a height floor, Telegram's 550 pt
/// answering a 324 pt Stack slot. The engine half is
/// `SizeBoundProbeInFlightTests`.
///
/// Every mutating call is hoisted into a `let`: one cannot sit
/// inside `#expect`.
@Suite("Size-bound probe hold (#2758)")
struct SizeBoundProbeHoldTests {
    private let w = WindowID(7)
    private let held = CGSize(width: 380, height: 550)
    private let slot = CGRect(x: 40, y: 300, width: 380, height: 324)

    /// The floor believed from one settled read with a trusted
    /// baseline, and its probe issued in place of `slot`.
    private func probeInFlight() throws -> SizeBoundLearner {
        var learner = SizeBoundLearner()
        learner.recordAsk(w, size: slot.size, settledFrom: held)
        learner.observe(w, currentSize: held, settledRead: true)
        let taken = learner.takeCorroborationProbe(
            w,
            current: held,
            target: slot.size,
            slot: slot
        )
        let issue = try #require(taken)
        learner.recordAsk(
            w,
            size: issue.size,
            settledFrom: issue.baseline
        )
        return learner
    }

    private func frame(
        dx: CGFloat = 0,
        dy: CGFloat = 0,
        size: CGSize? = nil
    ) -> CGRect {
        CGRect(
            origin: CGPoint(x: slot.minX + dx, y: slot.minY + dy),
            size: size ?? slot.size
        )
    }

    @Test("The slot's own spans and its reshaped residue are held")
    func slotAndResidueAreHeld() throws {
        var again = try probeInFlight()
        let same = again.holdForProbe(w, target: slot)
        #expect(same)
        // The answer drawn in the same slot: a residue placed, or
        // a park re-anchored at the answer's size.
        var reshaped = try probeInFlight()
        let residue = reshaped.holdForProbe(
            w,
            target: frame(dx: -20, size: held)
        )
        #expect(residue)
    }

    @Test("A moved slot or another span is not held")
    func movedSlotIsNotHeld() throws {
        var learner = try probeInFlight()
        // The slot's own size, moved: a pan, a neighbour closing.
        let shifted = learner.holdForProbe(w, target: frame(dy: 100))
        // The answer drawn one slot over: a swap.
        let swapped = learner.holdForProbe(
            w,
            target: frame(dy: slot.height + 8, size: held)
        )
        let taller = learner.holdForProbe(
            w,
            target: frame(size: CGSize(width: 380, height: 700))
        )
        let wider = learner.holdForProbe(
            w,
            target: frame(size: CGSize(width: 500, height: 550))
        )
        #expect(!shifted)
        #expect(!swapped)
        #expect(!taller)
        #expect(!wider)
    }

    @Test("A settled answer ends the hold and owes the held frame")
    func settledAnswerEndsTheHold() throws {
        var learner = try probeInFlight()
        let holds = learner.holdForProbe(w, target: slot)
        #expect(holds)
        // A raw echo answers nothing (#1083): still held.
        let raw = learner.observeAnswer(
            w,
            currentSize: held,
            settledRead: false
        )
        #expect(!raw.answeredHeldProbe)
        let stillHeld = learner.holdForProbe(w, target: slot)
        #expect(stillHeld)
        let settled = learner.observeAnswer(
            w,
            currentSize: held,
            settledRead: true
        )
        #expect(settled.answeredHeldProbe)
        #expect(settled.owesPlacement)
        #expect(learner.bound(for: w)?.minHeight == 550)
        let after = learner.holdForProbe(w, target: slot)
        #expect(!after)
    }

    @Test("The re-issue is held too, and pairs once answered")
    func reissueIsHeld() throws {
        // No trusted baseline: the anchor confirms over two settled
        // reads and its probe answers through the candidate ladder.
        var learner = SizeBoundLearner()
        learner.recordAsk(w, size: slot.size)
        learner.observe(w, currentSize: held, settledRead: true)
        learner.observe(w, currentSize: held, settledRead: true)
        let first = learner.takeCorroborationProbe(
            w,
            current: held,
            target: slot.size,
            slot: slot
        )
        let issue = try #require(first)
        learner.recordAsk(w, size: issue.size)
        learner.observe(w, currentSize: held, settledRead: true)
        // Answered once: the first issue holds nothing more, and
        // the "probing once more" pass re-issues.
        let answered = learner.holdForProbe(w, target: slot)
        #expect(!answered)
        let second = learner.takeCorroborationProbe(
            w,
            current: held,
            target: slot.size,
            slot: slot
        )
        let reissue = try #require(second)
        learner.recordAsk(w, size: reissue.size)
        let holds = learner.holdForProbe(w, target: slot)
        #expect(holds)
        // A pass before its answer neither re-issues nor retires.
        let early = learner.takeCorroborationProbe(
            w,
            current: held,
            target: slot.size,
            slot: slot
        )
        #expect(early == nil)
        let kept = learner.holdForProbe(w, target: slot)
        #expect(kept)
        learner.observe(w, currentSize: held, settledRead: true)
        #expect(learner.bound(for: w)?.minHeight == 550)
    }
}
