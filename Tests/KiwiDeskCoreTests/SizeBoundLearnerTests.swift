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
        #expect(bound?.width.first?.asked == 900)
        #expect(bound?.width.first?.answered == 715)
        // The complied axis learns nothing.
        #expect(bound?.height.isEmpty != false)
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
        #expect(learner.bound(for: w)?.width.first?.answered == 780)
    }

    @Test("Axes learn independently")
    func axesLearnIndependently() {
        var learner = SizeBoundLearner()
        let asked = CGSize(width: 900, height: 800)
        let answered = CGSize(width: 715, height: 600)
        refused(&learner, asked: asked, answered: answered)
        refused(&learner, asked: asked, answered: answered)
        let bound = learner.bound(for: w)
        #expect(bound?.width.first?.answered == 715)
        #expect(bound?.height.first?.answered == 600)
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

    @Test("Interleaved asks ladder independently")
    func interleavedAsksBothConfirm() {
        // The monocle dance that never stopped (device QA,
        // 2026-08-18): two layouts ask the same window
        // different sizes, and a single candidate slot per
        // axis let each ask overwrite the other's ladder — the
        // alternating pattern below never confirmed either.
        var learner = SizeBoundLearner()
        let scroll = CGSize(width: 900, height: 800)
        let monocle = CGSize(width: 1900, height: 1060)
        let scrollAnswer = CGSize(width: 715, height: 800)
        let monocleAnswer = CGSize(width: 715, height: 1060)
        refused(&learner, asked: scroll, answered: scrollAnswer)
        refused(
            &learner,
            asked: monocle,
            answered: monocleAnswer
        )
        refused(&learner, asked: scroll, answered: scrollAnswer)
        refused(
            &learner,
            asked: monocle,
            answered: monocleAnswer
        )
        let bound = learner.bound(for: w)
        #expect(bound?.consumedWidth(asking: 900) == 715)
        #expect(bound?.consumedWidth(asking: 1900) == 715)
        #expect(bound?.consumedHeight(asking: 1060) == nil)
    }

    @Test("Entries are capped, oldest evicted")
    func entriesAreCapped() {
        var learner = SizeBoundLearner()
        let asks: [CGFloat] = [900, 1000, 1100, 1200, 1300]
        for ask in asks {
            let asked = CGSize(width: ask, height: 800)
            let answered = CGSize(width: 715, height: 800)
            refused(&learner, asked: asked, answered: answered)
            refused(&learner, asked: asked, answered: answered)
        }
        let bound = learner.bound(for: w)
        // The oldest ask fell off the cap; the newest four hold.
        #expect(bound?.consumedWidth(asking: 900) == nil)
        #expect(bound?.consumedWidth(asking: 1000) == 715)
        #expect(bound?.consumedWidth(asking: 1300) == 715)
        #expect(
            bound?.width.count
                == SizeBoundLearner.maxEntriesPerAxis
        )
    }

    @Test("The candidate view carries a single refusal")
    func candidateViewCarriesOneRefusal() {
        // The overlay pin's provisional source (#677 device
        // QA): one refusal is enough for RENDERING — the ring
        // stops riding out on the second probe — while
        // `bound(for:)`, the geometry view, stays empty until
        // the confirm.
        var learner = SizeBoundLearner()
        let asked = CGSize(width: 900, height: 800)
        let answered = CGSize(width: 715, height: 800)
        refused(&learner, asked: asked, answered: answered)
        #expect(learner.bound(for: w) == nil)
        #expect(
            learner.candidateBound(for: w)?
                .consumedWidth(asking: 900) == 715
        )
        // Confirmation moves the entry across: the candidate
        // view drains, the geometry view fills.
        refused(&learner, asked: asked, answered: answered)
        #expect(learner.candidateBound(for: w) == nil)
        #expect(
            learner.bound(for: w)?
                .consumedWidth(asking: 900) == 715
        )
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
        #expect(learner.bound(for: new)?.width.first?.answered == 715)
    }
}
