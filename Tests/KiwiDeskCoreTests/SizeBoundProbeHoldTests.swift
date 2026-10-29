import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The issue out, through the take door (#2758): an ordinary pass
/// carries a corroboration probe's issue into every target that
/// still asks its span, until a settled read answers it. The
/// device's shape: a height floor, Telegram's 550 pt answering a
/// 324 pt Stack slot. The engine half is
/// `SizeBoundProbeInFlightTests`.
///
/// Every mutating call is hoisted into a `let`: one cannot sit
/// inside `#expect`.
@Suite("Size-bound probe hold (#2758)")
struct SizeBoundProbeHoldTests {
    private let w = WindowID(7)
    private let held = CGSize(width: 380, height: 550)
    private let slot = CGSize(width: 380, height: 324)

    /// The floor believed from one settled read with a trusted
    /// baseline, and its probe issued in place of `slot`.
    private func probeOut() throws -> SizeBoundLearner {
        var learner = SizeBoundLearner()
        learner.recordAsk(w, size: slot, settledFrom: held)
        learner.observe(w, currentSize: held, settledRead: true)
        let taken = learner.takeCorroborationProbe(
            w,
            current: held,
            target: slot
        )
        let issue = try #require(taken)
        learner.recordAsk(
            w,
            size: issue.size,
            settledFrom: issue.baseline
        )
        return learner
    }

    private func carry(
        _ learner: inout SizeBoundLearner,
        _ target: CGSize
    ) -> SizeBoundLearner.ProbeIssue? {
        learner.takeCorroborationProbe(
            w,
            current: held,
            target: target,
            keepsIssueOut: true
        )
    }

    private var probed: CGFloat {
        324 - SizeBoundLearner.probeDistance
    }

    @Test("A target that still asks the span carries the issue out")
    func spanStillAskedCarries() throws {
        var learner = try probeOut()
        // The slot again, and the anchor's answer (a residue).
        let again = carry(&learner, slot)
        let residue = carry(&learner, held)
        #expect(again?.size == CGSize(width: 380, height: probed))
        #expect(residue?.size == CGSize(width: 380, height: probed))
        #expect(again?.fresh == false)
        // The question already out: at the slot it may move with
        // the slot, at the answer it is a residue and stays.
        #expect(again?.alreadyOut == true)
        #expect(again?.residue == false)
        #expect(residue?.residue == true)
        // A neighbour's floor widened the column: the width
        // follows the layout, the height stays out.
        let wider = carry(&learner, CGSize(width: 400, height: 550))
        #expect(wider?.size == CGSize(width: 400, height: probed))
        #expect(wider?.alreadyOut == false)
        // A span the anchor does not answer carries nothing.
        let taller = carry(&learner, CGSize(width: 380, height: 700))
        #expect(taller == nil)
        // A re-issuing or forced pass sends its own ask.
        let reissue = learner.takeCorroborationProbe(
            w,
            current: held,
            target: slot
        )
        #expect(reissue == nil)
    }

    @Test("A settled answer ends the carry and owes the frame")
    func settledAnswerEnds() throws {
        var learner = try probeOut()
        let bent = carry(&learner, held)
        #expect(bent != nil)
        // A raw echo answers nothing (#1083): still out.
        let raw = learner.observeAnswer(
            w,
            currentSize: held,
            settledRead: false
        )
        #expect(!raw.answeredHeldProbe)
        let settled = learner.observeAnswer(
            w,
            currentSize: held,
            settledRead: true
        )
        #expect(settled.answeredHeldProbe)
        #expect(learner.bound(for: w)?.minHeight == 550)
        let after = carry(&learner, held)
        #expect(after == nil)
    }

    @Test("A held answer that confirms nothing still owes the frame")
    func unconfirmedHeldAnswerOwes() throws {
        var learner = try probeOut()
        let bent = carry(&learner, slot)
        #expect(bent != nil)
        // A grid app answering off the anchor's answer: nothing
        // confirms, only the frame bent to the issue is owed.
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

    @Test("An overwritten issue is re-sent, a bounded number of times")
    func overwrittenIssueIsResent() throws {
        // Brave on the device: its run re-packed to a taller slot
        // while the probe was out, then came back.
        var learner = try probeOut()
        let taller = CGSize(width: 380, height: 579)
        for round in 0..<SizeBoundLearner.maxProbeResends {
            learner.recordAsk(w, size: taller)
            let none = carry(&learner, taller)
            #expect(none == nil)
            let resent = carry(&learner, slot)
            #expect(resent?.size.height == probed, "round \(round)")
            learner.recordAsk(w, size: try #require(resent).size)
        }
        // Spent: the next overwrite retires the probe.
        var spentLearner = learner
        spentLearner.recordAsk(w, size: taller)
        let spent = carry(&spentLearner, slot)
        #expect(spent == nil)
        #expect(spentLearner.probes[w]?.height.pending == nil)
        // The last re-send's own answer still counts: it cues the
        // re-issue rather than retiring the probe.
        learner.observe(w, currentSize: held, settledRead: true)
        let reissue = carry(&learner, slot)
        #expect(reissue?.fresh == true)
    }

    @Test("The re-issue is carried too, and pairs once answered")
    func reissueIsCarried() throws {
        // No trusted baseline: the anchor confirms over two settled
        // reads and its probe answers through the candidate ladder.
        var learner = SizeBoundLearner()
        learner.recordAsk(w, size: slot)
        learner.observe(w, currentSize: held, settledRead: true)
        learner.observe(w, currentSize: held, settledRead: true)
        let first = learner.takeCorroborationProbe(
            w,
            current: held,
            target: slot
        )
        let issue = try #require(first)
        learner.recordAsk(w, size: issue.size)
        learner.observe(w, currentSize: held, settledRead: true)
        // Answered once: the "probing once more" pass re-issues.
        let second = carry(&learner, slot)
        let reissue = try #require(second)
        #expect(reissue.fresh)
        learner.recordAsk(w, size: reissue.size)
        // Before its answer it is carried, neither re-issued nor
        // retired.
        let early = carry(&learner, slot)
        #expect(early?.fresh == false)
        learner.observe(w, currentSize: held, settledRead: true)
        #expect(learner.bound(for: w)?.minHeight == 550)
    }

    @Test("A new issue on one axis carries the other's issue out")
    func newIssueCarriesTheOtherAxis() throws {
        var learner = try probeOut()
        learner.promote(
            w,
            asked: 336,
            answered: 380,
            axis: \.width,
            settledRead: true
        )
        let narrow = CGSize(width: 336, height: 324)
        let taken = carry(&learner, narrow)
        let issue = try #require(taken)
        #expect(issue.fresh)
        let width = 336 - SizeBoundLearner.probeDistance
        #expect(issue.size == CGSize(width: width, height: probed))
    }

    @Test("A width ceiling's carried answer is owed too")
    func widthCeilingCarriedAnswer() throws {
        var learner = SizeBoundLearner()
        let asked = CGSize(width: 1000, height: 800)
        let answered = CGSize(width: 715, height: 800)
        learner.recordAsk(w, size: asked, settledFrom: answered)
        learner.observe(w, currentSize: answered, settledRead: true)
        let taken = learner.takeCorroborationProbe(
            w,
            current: answered,
            target: asked
        )
        let issue = try #require(taken)
        learner.recordAsk(
            w,
            size: issue.size,
            settledFrom: issue.baseline
        )
        let bent = learner.takeCorroborationProbe(
            w,
            current: answered,
            target: answered,
            keepsIssueOut: true
        )
        #expect(bent?.size.width == issue.size.width)
        let answer = learner.observeAnswer(
            w,
            currentSize: answered,
            settledRead: true
        )
        #expect(answer.answeredHeldProbe)
        #expect(learner.bound(for: w)?.maxWidth == 715)
    }
}
