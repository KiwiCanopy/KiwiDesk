import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The confirm ladder (#677): the same ask refused with the
/// same answer twice in a row is a bound; anything less is not.
/// The pure half — what a bound then MEANS is
/// `EffectiveSizeBoundTests`, and `RetileBoundSkipTests` proves
/// the engine consults it.
@Suite("Size-bound learner ladder (#677)")
struct SizeBoundLearnerTests {
    private let w = WindowID(7)

    private func refused(
        _ learner: inout SizeBoundLearner,
        asked: CGSize,
        answered: CGSize
    ) {
        learner.recordAsk(w, size: asked)
        learner.observe(w, currentSize: answered)
    }

    @Test("Twice in a row confirms; once does not")
    func twiceInARowConfirms() {
        var learner = SizeBoundLearner()
        let asked = CGSize(width: 900, height: 800)
        let answered = CGSize(width: 715, height: 800)
        refused(&learner, asked: asked, answered: answered)
        #expect(learner.bound(for: w) == nil)
        refused(&learner, asked: asked, answered: answered)
        let bound = learner.bound(for: w)
        #expect(bound?.width?.asked == 900)
        #expect(bound?.width?.answered == 715)
        // The complied axis learns nothing.
        #expect(bound?.height == nil)
    }

    @Test("A different answer restarts the ladder")
    func differentAnswerRestarts() {
        var learner = SizeBoundLearner()
        let asked = CGSize(width: 900, height: 800)
        refused(
            &learner,
            asked: asked,
            answered: CGSize(width: 715, height: 800)
        )
        // A cancel mid-flight can leave a stray intermediate
        // size — one observation must not pair with a different
        // one to fake a confirmation.
        refused(
            &learner,
            asked: asked,
            answered: CGSize(width: 780, height: 800)
        )
        #expect(learner.bound(for: w) == nil)
        refused(
            &learner,
            asked: asked,
            answered: CGSize(width: 780, height: 800)
        )
        #expect(learner.bound(for: w)?.width?.answered == 780)
    }

    @Test("Axes learn independently")
    func axesLearnIndependently() {
        var learner = SizeBoundLearner()
        let asked = CGSize(width: 900, height: 800)
        let answered = CGSize(width: 715, height: 600)
        refused(&learner, asked: asked, answered: answered)
        refused(&learner, asked: asked, answered: answered)
        let bound = learner.bound(for: w)
        #expect(bound?.width?.answered == 715)
        #expect(bound?.height?.answered == 600)
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
        #expect(learner.bound(for: w)?.width?.answered == 715)
    }

    @Test("A zero-size frame is no answer")
    func zeroSizeFrameIsNoAnswer() {
        // A window created and never echoed keeps a .zero
        // state frame; reading that as "the app answered 0"
        // would confirm a 0 pt bound and collapse the slot
        // (caught by ScrollingFloatingFocusTests' end-to-end
        // fixture on this suite's first full run).
        var learner = SizeBoundLearner()
        let asked = CGSize(width: 900, height: 800)
        refused(&learner, asked: asked, answered: .zero)
        refused(&learner, asked: asked, answered: .zero)
        #expect(learner.bound(for: w) == nil)
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
        #expect(learner.bound(for: new)?.width?.answered == 715)
    }
}
