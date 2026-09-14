import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The corroboration probe's bookkeeping (#1439): a confirmation
/// on an uncorroborated axis arms ONE deliberate second ask, the
/// engine takes it only in place of an ask the anchor already
/// answers, and the question closes with its answer — corroborated
/// or not — without chaining. The pure half; the engine's door and
/// the log are `SizeBoundCorroborationProbeEngineTests`.
///
/// Every take is hoisted into a `let`: a mutating call cannot sit
/// inside `#expect`.
@Suite("Size-bound corroboration probe (#1439)")
struct SizeBoundCorroborationProbeTests {
    private let w = WindowID(7)
    private let bar = EffectiveSizeBound.corroborationDistinctness
    private let held = CGSize(width: 720, height: 800)
    private let ask = CGSize(width: 500, height: 800)

    /// A floor entry believed from one settled read with a
    /// trusted baseline: the window held 720 before the 500 ask
    /// and still does.
    private func believedFloor() -> SizeBoundLearner {
        var learner = SizeBoundLearner()
        learner.recordAsk(w, size: ask, settledFrom: held)
        learner.observe(w, currentSize: held, settledRead: true)
        return learner
    }

    private func take(
        _ learner: inout SizeBoundLearner,
        current: CGSize? = nil,
        target: CGSize? = nil
    ) -> SizeBoundLearner.ProbeIssue? {
        learner.takeCorroborationProbe(
            w,
            current: current ?? held,
            target: target ?? ask
        )
    }

    @Test("A confirmation arms one probe past the distinctness bar")
    func confirmationArmsOneProbe() throws {
        var floor = believedFloor()
        // Uncorroborated: a single entry answers no consumer.
        #expect(floor.bound(for: w)?.minWidth == nil)
        let issue = try #require(take(&floor))
        // A floor probes SMALLER, one point past the bar, on the
        // refusing axis alone. Derived from the constant so a
        // retune moves both.
        #expect(issue.size.width == 500 - bar - 1)
        #expect(issue.size.height == 800)

        // The ceiling mirror probes LARGER.
        var ceiling = SizeBoundLearner()
        let snapped = CGSize(width: 715, height: 800)
        ceiling.recordAsk(
            w,
            size: CGSize(width: 1000, height: 800),
            settledFrom: snapped
        )
        ceiling.observe(w, currentSize: snapped, settledRead: true)
        let mirrored = try #require(
            take(&ceiling, current: snapped, target: snapped)
        )
        #expect(mirrored.size.width == 1000 + bar + 1)
    }

    @Test("The expected answer corroborates in one settled read")
    func expectedAnswerCorroborates() throws {
        var learner = believedFloor()
        let issue = try #require(take(&learner))
        // The anchor's confirming read was settled, so the
        // pre-ask frame is a trusted first observation.
        #expect(issue.baseline == held)
        learner.recordAsk(
            w,
            size: issue.size,
            settledFrom: issue.baseline
        )
        let confirmed = learner.observe(
            w,
            currentSize: held,
            settledRead: true
        )
        #expect(confirmed)
        // Two asks a real step apart agreeing: the floor every
        // consumer reads.
        #expect(learner.bound(for: w)?.minWidth == 720)
        // The question is closed — nothing further is asked.
        let again = take(&learner)
        #expect(again == nil)
    }

    @Test("A grid answer retires the probe without corroborating")
    func gridAnswerRetiresWithoutCorroborating() throws {
        // Terminal-shaped: the ask 1000 answered 997 (a ceiling
        // entry), the probe 1013 answered 1008 — a few points
        // off, exactly the pair #1055 refuses. (An answer INSIDE
        // the match tolerance is a compliance to the sweep, which
        // is the orphaned-anchor case below.)
        var learner = SizeBoundLearner()
        let snapped = CGSize(width: 997, height: 800)
        learner.recordAsk(
            w,
            size: CGSize(width: 1000, height: 800),
            settledFrom: snapped
        )
        learner.observe(w, currentSize: snapped, settledRead: true)
        let answer = CGSize(width: 1008, height: 800)
        for _ in 0..<2 {
            let issue = try #require(
                take(&learner, current: snapped, target: snapped)
            )
            learner.recordAsk(w, size: issue.size)
            learner.observe(w, currentSize: answer, settledRead: true)
        }
        // The probe's own ask is believed like any refusal…
        let entries = learner.bound(for: w)?.width ?? []
        #expect(entries.count == 2)
        // …and corroborates nothing.
        #expect(learner.bound(for: w)?.maxWidth == nil)
        // The probe's confirmation armed no probe of its own: the
        // chain ends at the second ask.
        let chained = take(&learner, current: answer, target: answer)
        #expect(chained == nil)
    }

    @Test("A probe is re-issued once, and only once answered")
    func reissuedOnceAndOnlyOnceAnswered() throws {
        var learner = believedFloor()
        let first = try #require(take(&learner))
        // An unrelated retile before the first answer re-asks
        // nothing: the settle read is still coming.
        let early = take(&learner)
        #expect(early == nil)
        // The first read seeded the probe's candidate (no trusted
        // baseline here — a raw echo): the "probing once more"
        // retile re-issues, once.
        learner.recordAsk(w, size: first.size)
        learner.observe(w, currentSize: held, settledRead: false)
        let second = take(&learner)
        let third = take(&learner)
        #expect(second != nil)
        #expect(third == nil)
        // Only the FIRST issue carries the trusted baseline; the
        // re-issue answers through the candidate ladder.
        #expect(first.baseline != nil)
        #expect(second?.baseline == nil)
    }

    @Test("A probe never displaces an ask the anchor does not answer")
    func neverDisplacesANewAsk() {
        var learner = believedFloor()
        // A genuinely new ask goes out as the layout meant it.
        let fresh = take(
            &learner,
            target: CGSize(width: 600, height: 800)
        )
        #expect(fresh == nil)
        // The probe is still pending for the ask it may replace
        // — the anchor's own, or its answer (a consumed slot).
        let consumed = take(&learner, target: held)
        #expect(consumed != nil)
    }

    @Test("A corroborated axis arms nothing")
    func corroboratedAxisArmsNothing() {
        var learner = believedFloor()
        // A second distinct ask the layout happened to send,
        // refused with the same span: corroborated without the
        // probe, so the pending one is dropped.
        learner.recordAsk(
            w,
            size: CGSize(width: 400, height: 800),
            settledFrom: held
        )
        learner.observe(w, currentSize: held, settledRead: true)
        #expect(learner.bound(for: w)?.minWidth == 720)
        let issue = take(&learner)
        #expect(issue == nil)
    }

    @Test("A raw-pair confirmation arms an untrusted probe")
    func rawPairArmsUntrusted() throws {
        // The #1049 comply-then-revoke promote reads a raw echo:
        // the frame it saw may be mid-revoke, so the probe's first
        // read must earn its own candidate rather than lean on it.
        var learner = SizeBoundLearner()
        learner.recordAsk(w, size: ask)
        learner.observe(w, currentSize: ask, settledRead: false)
        let confirmed = learner.observe(
            w,
            currentSize: held,
            settledRead: false
        )
        #expect(confirmed)
        let issue = try #require(take(&learner))
        #expect(issue.baseline == nil)
    }

    @Test("An ordinary ask in between distrusts the baseline")
    func ordinaryAskDistrusts() throws {
        var learner = believedFloor()
        // The layout asked something else first (a pass that did
        // not probe this window); the frame that earned the trust
        // is no longer the last settled read.
        learner.recordAsk(w, size: CGSize(width: 650, height: 800))
        let issue = try #require(take(&learner))
        #expect(issue.baseline == nil)
    }

    @Test("A compliance that lifts the anchor retires the probe")
    func complianceRetiresTheProbe() {
        var learner = believedFloor()
        // The app now performs a smaller ask: the floor lifted,
        // the entry is swept, and the probe is orphaned.
        let performed = CGSize(width: 480, height: 800)
        learner.recordAsk(w, size: performed)
        learner.observe(w, currentSize: performed, settledRead: true)
        #expect(learner.bound(for: w) == nil)
        let orphaned = take(&learner, current: performed)
        #expect(orphaned == nil)
        // A re-confirmation of the same anchor arms NOTHING: a
        // grid app answers the probe inside the tolerance, the
        // sweep reads that as the constraint lifting, the layout
        // re-confirms — and a record that left with its anchor
        // would dance that cycle forever.
        learner.recordAsk(w, size: ask, settledFrom: held)
        learner.observe(w, currentSize: held, settledRead: true)
        let rearmed = take(&learner)
        #expect(rearmed == nil)
        // A DIFFERENT anchor on the axis gets its own probe — a
        // ceiling here, since a second floor answering 720 would
        // corroborate the first outright.
        let wider = CGSize(width: 900, height: 800)
        let capped = CGSize(width: 800, height: 800)
        for _ in 0..<2 {
            learner.recordAsk(w, size: wider)
            learner.observe(w, currentSize: capped, settledRead: true)
        }
        let fresh = take(&learner, current: capped, target: wider)
        #expect(fresh?.size.width == 900 + bar + 1)
    }

}
