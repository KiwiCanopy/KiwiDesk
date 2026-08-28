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
        learner.observe(
            w,
            currentSize: answered,
            settledRead: true
        )
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
        // One past the cap, derived so a retuned cap keeps the
        // test honest.
        let count = SizeBoundLearner.maxEntriesPerAxis + 1
        let asks = (0..<count).map { CGFloat(900 + $0 * 100) }
        for ask in asks {
            let asked = CGSize(width: ask, height: 800)
            let answered = CGSize(width: 715, height: 800)
            refused(&learner, asked: asked, answered: answered)
            refused(&learner, asked: asked, answered: answered)
        }
        let bound = learner.bound(for: w)
        // The oldest ENTRY fell off; its ask still consumes
        // via the corroborated ceiling (#1055 Lane B).
        let oldest = bound?.width.contains {
            EffectiveSizeBound.matches($0.asked, asks[0])
        }
        #expect(oldest == false)
        #expect(bound?.consumedWidth(asking: asks[0]) == 715)
        #expect(bound?.consumedWidth(asking: asks[1]) == 715)
        #expect(
            bound?.consumedWidth(asking: asks[count - 1])
                == 715
        )
        #expect(
            bound?.width.count
                == SizeBoundLearner.maxEntriesPerAxis
        )
    }

    @Test("Unconfirmed candidates are capped too")
    func candidatesAreCapped() {
        // The candidate-side cap was unexercised: every other
        // fixture confirms each ask before the next, so the
        // candidate list never grows past one (review,
        // 2026-08-18).
        var learner = SizeBoundLearner()
        let count = SizeBoundLearner.maxEntriesPerAxis + 1
        let asks = (0..<count).map { CGFloat(900 + $0 * 100) }
        for ask in asks {
            refused(
                &learner,
                asked: CGSize(width: ask, height: 800),
                answered: CGSize(width: 715, height: 800)
            )
        }
        // A surviving candidate confirms on its second
        // observation… (checked first: re-observing the
        // EVICTED ask below evicts another survivor)
        refused(
            &learner,
            asked: CGSize(
                width: asks[count - 1],
                height: 800
            ),
            answered: CGSize(width: 715, height: 800)
        )
        #expect(
            learner.bound(for: w)?
                .consumedWidth(asking: asks[count - 1]) == 715
        )
        // …while the evicted first ask's cannot — its ladder
        // restarted from zero.
        refused(
            &learner,
            asked: CGSize(width: asks[0], height: 800),
            answered: CGSize(width: 715, height: 800)
        )
        #expect(
            learner.bound(for: w)?
                .consumedWidth(asking: asks[0]) == nil
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

    @Test("Observe reports the confirmation edge exactly once")
    func observeReportsTheConfirmationEdge() {
        // The caller answers a confirm with an immediate
        // retile — so the edge must fire on the believing
        // observation, and NEVER on a re-observation of the
        // same believed answer, or the retile loops on its own
        // echoes.
        var learner = SizeBoundLearner()
        let asked = CGSize(width: 900, height: 800)
        let answered = CGSize(width: 715, height: 800)
        learner.recordAsk(w, size: asked)
        #expect(
            learner.observe(
                w,
                currentSize: answered,
                settledRead: true
            ) == false
        )
        learner.recordAsk(w, size: asked)
        #expect(
            learner.observe(
                w,
                currentSize: answered,
                settledRead: true
            ) == true
        )
        learner.recordAsk(w, size: asked)
        #expect(
            learner.observe(
                w,
                currentSize: answered,
                settledRead: true
            ) == false
        )
        // A CHANGED answer that re-confirms is a new edge — the
        // geometry it implies moved.
        let changed = CGSize(width: 640, height: 800)
        learner.recordAsk(w, size: asked)
        learner.observe(
            w,
            currentSize: changed,
            settledRead: true
        )
        learner.recordAsk(w, size: asked)
        #expect(
            learner.observe(
                w,
                currentSize: changed,
                settledRead: true
            ) == true
        )
    }

    @Test("The probe gate wants only unexplained refusals")
    func probeGateWantsOnlyUnexplainedRefusals() {
        var learner = SizeBoundLearner()
        let asked = CGSize(width: 900, height: 800)
        let answered = CGSize(width: 715, height: 800)
        // No ask on record: nothing to answer.
        #expect(!learner.wantsProbe(w, currentSize: answered))
        learner.recordAsk(w, size: asked)
        // Complying state frame: the echo landed, no probe.
        #expect(!learner.wantsProbe(w, currentSize: asked))
        // Off the ask and unexplained: probe.
        #expect(learner.wantsProbe(w, currentSize: answered))
        // Believed: the refusal is explained, probing stops.
        refused(&learner, asked: asked, answered: answered)
        refused(&learner, asked: asked, answered: answered)
        #expect(!learner.wantsProbe(w, currentSize: answered))
    }

    @Test("A comply-then-revoke pair confirms in one cycle")
    func complyThenRevokePairConfirms() {
        // The #1049 single-dance shortcut: the ladder needs the
        // same answer twice because one refusal can be a stale
        // pre-ask frame — but an echo-channel compliance proves
        // the window truly held the asked size, so the off-ask
        // echo that follows within the same ask is the app
        // actively revoking: one answer, definitively
        // attributed.
        var learner = SizeBoundLearner()
        let asked = CGSize(width: 1626, height: 1005)
        let snapped = CGSize(width: 439, height: 1005)
        learner.recordAsk(w, size: asked)
        learner.observe(
            w,
            currentSize: asked,
            settledRead: false
        )
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
        // A fresh ask resets the pair — the flag must not
        // carry a stale compliance into the next question. The
        // compliance echo BEFORE the fresh ask is load-bearing
        // (review, 2026-08-27): without it the flag is already
        // consumed by the promotion above and the clause passes
        // whether or not `recordAsk` resets anything.
        learner.forget(w)
        learner.recordAsk(w, size: asked)
        learner.observe(
            w,
            currentSize: asked,
            settledRead: false
        )
        learner.recordAsk(w, size: asked)
        #expect(
            learner.observe(
                w,
                currentSize: snapped,
                settledRead: false
            ) == false
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

}
