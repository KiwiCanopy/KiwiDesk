import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The ledger's UNLEARNING (#677), split from
/// `SizeBoundLearnerTests` at the file ceiling: compliance
/// clearing, the cross-ask contradiction sweep and its
/// deliberate grid-snap trade, the late-echo classifier, and
/// the forget/rekey lifecycle. The learning ladder stays next
/// door.
@Suite("Size-bound invalidation (#677)")
struct SizeBoundInvalidationTests {
    private let w = WindowID(7)

    private func refused(
        _ learner: inout SizeBoundLearner,
        asked: CGSize,
        answered: CGSize
    ) {
        learner.recordAsk(w, size: asked)
        learner.observe(
            w,
            currentSize: answered,
            settledRead: true
        )
    }

    @Test("Compliance clears the candidate")
    func complianceClearsCandidate() {
        var learner = SizeBoundLearner()
        let asked = CGSize(width: 900, height: 800)
        refused(
            &learner,
            asked: asked,
            answered: CGSize(width: 715, height: 800)
        )
        // The app performs the ask this time — the earlier
        // refusal was transient, so the ladder restarts.
        refused(&learner, asked: asked, answered: asked)
        refused(
            &learner,
            asked: asked,
            answered: CGSize(width: 715, height: 800)
        )
        #expect(learner.bound(for: w) == nil)
    }

    @Test("A contradicted bound is cleared by compliance")
    func contradictionClearsBound() {
        var learner = SizeBoundLearner()
        let asked = CGSize(width: 900, height: 800)
        let answered = CGSize(width: 715, height: 800)
        refused(&learner, asked: asked, answered: answered)
        refused(&learner, asked: asked, answered: answered)
        #expect(learner.bound(for: w) != nil)
        // The app later performs 800 — above the learned
        // ceiling of 715, so the constraint has lifted and the
        // bound must go, or a stale skip pins the window small.
        let wider = CGSize(width: 800, height: 800)
        refused(&learner, asked: wider, answered: wider)
        #expect(learner.bound(for: w) == nil)
    }

    @Test("Compliance below a ceiling keeps the bound")
    func complianceBelowCeilingKeeps() {
        var learner = SizeBoundLearner()
        let asked = CGSize(width: 900, height: 800)
        let answered = CGSize(width: 715, height: 800)
        refused(&learner, asked: asked, answered: answered)
        refused(&learner, asked: asked, answered: answered)
        // The layout consumed the bound and asked 715, which
        // the app performs. That contradicts nothing — the
        // ceiling still stands for the 900 ask.
        refused(&learner, asked: answered, answered: answered)
        #expect(learner.bound(for: w)?.width.first?.answered == 715)
    }

    @Test("A transient compliance does not clear the candidate")
    func transientComplianceKeepsCandidate() {
        // The Android emulator (#1049): it ANIMATES to the full
        // asked size, holds it ~0.4 s, then snaps back to its
        // aspect ratio — so every probe cycle echoes a
        // compliance before the real refusal. An echo-channel
        // read is not past the app's chance to revert, so it
        // must not run the complied sweep, or the ladder wipes
        // every cycle and "twice in a row" never accumulates.
        var learner = SizeBoundLearner()
        let asked = CGSize(width: 1626, height: 1005)
        let snapped = CGSize(width: 439, height: 1005)
        refused(&learner, asked: asked, answered: snapped)
        // The transient compliance echo, mid-snap-back.
        learner.recordAsk(w, size: asked)
        learner.observe(
            w,
            currentSize: asked,
            settledRead: false
        )
        // The snap-back echo is the second matching answer.
        #expect(
            learner.observe(
                w,
                currentSize: snapped,
                settledRead: false
            ) == true
        )
        #expect(
            learner.bound(for: w)?
                .consumedWidth(asking: 1626) == 439
        )
    }

    @Test("A transient compliance does not clear a bound")
    func transientComplianceKeepsBound() {
        // The believed half of the same rule (#1049): the
        // emulator transiently holds the asked size on every
        // re-ask, and clearing the confirmed entry on that echo
        // would re-open the endless re-issue the skip closed.
        // A SETTLED compliance at the same size still clears —
        // that is `contradictionClearsBound` above.
        var learner = SizeBoundLearner()
        let asked = CGSize(width: 1626, height: 1005)
        let snapped = CGSize(width: 439, height: 1005)
        refused(&learner, asked: asked, answered: snapped)
        refused(&learner, asked: asked, answered: snapped)
        #expect(learner.bound(for: w) != nil)
        learner.recordAsk(w, size: asked)
        learner.observe(
            w,
            currentSize: asked,
            settledRead: false
        )
        #expect(
            learner.bound(for: w)?
                .consumedWidth(asking: 1626) == 439
        )
    }

    @Test("A ledger-predicted size explains a late resize")
    func ledgerPredictedSizeExplainsResize() {
        // The forget gate's second term (#618 read queue): a
        // late echo of our own ask must not read as a genuine
        // resize and wipe the learning it is evidence for.
        var learner = SizeBoundLearner()
        let asked = CGSize(width: 900, height: 800)
        let answered = CGSize(width: 715, height: 800)
        refused(&learner, asked: asked, answered: answered)
        // The answer, arriving late — explained even while only
        // a candidate holds it.
        #expect(learner.explainsResize(w, size: answered))
        // The ask itself, complied late — explained.
        #expect(learner.explainsResize(w, size: asked))
        // A size nobody asked and nobody answered — genuine.
        #expect(
            !learner.explainsResize(
                w,
                size: CGSize(width: 830, height: 700)
            )
        )
    }

    @Test("Forget drops everything learned")
    func forgetDrops() {
        var learner = SizeBoundLearner()
        let asked = CGSize(width: 900, height: 800)
        let answered = CGSize(width: 715, height: 800)
        refused(&learner, asked: asked, answered: answered)
        refused(&learner, asked: asked, answered: answered)
        learner.forget(w)
        #expect(learner.bound(for: w) == nil)
        // The ladder restarts from zero — one observation after
        // a forget must not confirm against pre-forget history.
        refused(&learner, asked: asked, answered: answered)
        #expect(learner.bound(for: w) == nil)
    }

    @Test("Rekey migrates the ledger")
    func rekeyMigrates() {
        var learner = SizeBoundLearner()
        let new = WindowID(9)
        let asked = CGSize(width: 900, height: 800)
        let answered = CGSize(width: 715, height: 800)
        refused(&learner, asked: asked, answered: answered)
        refused(&learner, asked: asked, answered: answered)
        learner.rekey(old: w, new: new)
        #expect(learner.bound(for: w) == nil)
        #expect(learner.bound(for: new)?.width.first?.answered == 715)
    }
}
