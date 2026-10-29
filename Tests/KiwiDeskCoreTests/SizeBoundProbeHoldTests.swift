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

    @Test("A probe an ordinary ask superseded holds nothing")
    func supersededProbeHoldsNothing() throws {
        var learner = try probeInFlight()
        learner.recordAsk(w, size: CGSize(width: 380, height: 400))
        let holds = learner.holdForProbe(w, target: slot)
        #expect(!holds)
        let carried = learner.carryProbe(w, target: slot)
        #expect(carried == nil)
    }

    @Test("A held answer that confirms nothing still owes the frame")
    func unconfirmedHeldAnswerOwes() throws {
        var learner = try probeInFlight()
        let holds = learner.holdForProbe(w, target: slot)
        #expect(holds)
        // A grid app answering the probe off the anchor's answer:
        // no confirmation, only the held frame owed.
        let answer = learner.observeAnswer(
            w,
            currentSize: CGSize(width: 380, height: 560),
            settledRead: true
        )
        #expect(answer.answeredHeldProbe)
        #expect(!answer.confirmed)
        #expect(!answer.performedProbe)
        #expect(answer.owesPlacement)
    }

    @Test("A width ceiling's held answer is owed too")
    func widthCeilingHeldAnswer() throws {
        var learner = SizeBoundLearner()
        let asked = CGSize(width: 1000, height: 800)
        let answered = CGSize(width: 715, height: 800)
        let frame = CGRect(origin: .zero, size: asked)
        learner.recordAsk(w, size: asked, settledFrom: answered)
        learner.observe(w, currentSize: answered, settledRead: true)
        let taken = learner.takeCorroborationProbe(
            w,
            current: answered,
            target: asked,
            slot: frame
        )
        let issue = try #require(taken)
        learner.recordAsk(
            w,
            size: issue.size,
            settledFrom: issue.baseline
        )
        let holds = learner.holdForProbe(w, target: frame)
        #expect(holds)
        let answer = learner.observeAnswer(
            w,
            currentSize: answered,
            settledRead: true
        )
        #expect(answer.answeredHeldProbe)
        #expect(learner.bound(for: w)?.maxWidth == 715)
    }

    @Test("A target changed on another axis carries the probe")
    func changedAxisCarriesTheProbe() throws {
        // The device's second door: a neighbour's width floor
        // widens the column while the height probe is out.
        var learner = try probeInFlight()
        let probed = try #require(learner.lastAsks[w]?.size.height)
        let widened = frame(size: CGSize(width: 400, height: 550))
        let holds = learner.holdForProbe(w, target: widened)
        #expect(!holds)
        let carry = learner.carryProbe(w, target: widened)
        let carried = try #require(carry)
        #expect(carried.width == 400)
        #expect(carried.height == probed)
        // Sent as the engine sends it, untrusted: the carried
        // frame is now the slot, so the next pass holds.
        learner.recordAsk(w, size: carried.size)
        let next = learner.holdForProbe(w, target: widened)
        #expect(next)
        // A target that no longer stands in carries nothing.
        let taller = frame(size: CGSize(width: 400, height: 700))
        let none = learner.carryProbe(w, target: taller)
        #expect(none == nil)
        // The settled refusal is the issue's answer and owes the
        // held frame; the re-issue then pairs the floor.
        let answer = learner.observeAnswer(
            w,
            currentSize: CGSize(width: 400, height: 550),
            settledRead: true
        )
        #expect(answer.answeredHeldProbe)
        let again = learner.takeCorroborationProbe(
            w,
            current: CGSize(width: 400, height: 550),
            target: widened.size,
            slot: widened
        )
        let reissue = try #require(again)
        learner.recordAsk(w, size: reissue.size)
        learner.observe(
            w,
            currentSize: CGSize(width: 400, height: 550),
            settledRead: true
        )
        #expect(learner.bound(for: w)?.minHeight == 550)
    }
}
