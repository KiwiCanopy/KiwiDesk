import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The corroboration probe's lifetime (#1439), split from
/// `SizeBoundCorroborationProbeTests` at the file ceiling: the
/// ledger hooks it rides, the retile a performed probe files, the
/// per-anchor probed list under alternating layouts, and the
/// overlay pin. Same fixture, copied per file as tests.md wants.
@Suite("Size-bound corroboration probe, lifecycle (#1439)")
struct SizeBoundCorroborationProbeLifecycleTests {
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

    @Test("The probe follows the ledger's lifecycle")
    func followsTheLifecycle() {
        // Forget clears it with everything else.
        var forgotten = believedFloor()
        forgotten.forget(w)
        #expect(forgotten.probes[w] == nil)
        // A rekey carries it to the new id.
        var rekeyed = believedFloor()
        let new = WindowID(8)
        rekeyed.rekey(old: w, new: new)
        #expect(rekeyed.probes[w] == nil)
        let carried = rekeyed.takeCorroborationProbe(
            new,
            current: held,
            target: ask
        )
        #expect(carried != nil)
        // A gone window parks it beside its believed ledger and
        // the same window's re-add revives both — so a flapped
        // window does not wait for the layout to change either.
        var parked = believedFloor()
        let now = Date()
        parked.stashOnGone(w, pid: 42, now: now)
        #expect(parked.probes[w] == nil)
        parked.revive(w, pid: 42, now: now.addingTimeInterval(1))
        let revived = take(&parked)
        #expect(revived != nil)
    }

    @Test("A performed probe files the retile it owes")
    func performedProbeFilesARetile() throws {
        // The window PERFORMED the probe's ask — a grid app
        // landing inside the tolerance, or a lifted floor — and
        // now holds a size no layout drew, which the compliance
        // sweep's "nothing to place" cannot see. Both channels:
        // the settled read runs the sweep, the raw echo cannot
        // wait for one (`wantsProbe` reads it as done).
        var settled = believedFloor()
        let issue = try #require(take(&settled))
        settled.recordAsk(w, size: issue.size)
        settled.observe(w, currentSize: issue.size, settledRead: true)
        #expect(settled.compliedProbes.contains(w))
        // Closed: the anchor was swept, and the ask stays probed.
        let again = take(&settled)
        #expect(again == nil)

        var raw = believedFloor()
        let rawIssue = try #require(take(&raw))
        raw.recordAsk(w, size: rawIssue.size)
        raw.observe(w, currentSize: rawIssue.size, settledRead: false)
        #expect(raw.compliedProbes.contains(w))
        // An ordinary compliance files nothing.
        var plain = believedFloor()
        plain.recordAsk(w, size: CGSize(width: 900, height: 800))
        plain.observe(
            w,
            currentSize: CGSize(width: 900, height: 800),
            settledRead: false
        )
        #expect(!plain.compliedProbes.contains(w))
    }

    @Test("Alternating anchors keep their one probe each")
    func alternatingAnchorsKeepTheirProbes() throws {
        // Two layouts alternate their asks on one axis (the
        // per-ask ladder's own case): each anchor's probe, once
        // retired, stays retired through the other's — the
        // probed list is per anchor, not one record per axis.
        var learner = believedFloor()
        let first = try #require(take(&learner))
        learner.recordAsk(w, size: first.size, settledFrom: first.baseline)
        learner.observe(w, currentSize: held, settledRead: true)
        #expect(learner.bound(for: w)?.minWidth == 720)
        // The second anchor: a ceiling at 900 answered 800.
        let wider = CGSize(width: 900, height: 800)
        let capped = CGSize(width: 800, height: 800)
        for _ in 0..<2 {
            learner.recordAsk(w, size: wider)
            learner.observe(w, currentSize: capped, settledRead: true)
        }
        let second = try #require(
            take(&learner, current: capped, target: wider)
        )
        #expect(second.size.width == 900 + bar + 1)
        learner.recordAsk(w, size: second.size)
        learner.observe(w, currentSize: capped, settledRead: true)
        // Back to the first anchor, re-confirmed after its sweep:
        // no third probe for it.
        learner.recordAsk(w, size: ask, settledFrom: held)
        learner.observe(w, currentSize: held, settledRead: true)
        let third = take(&learner)
        #expect(third == nil)
    }

    @Test("A probe in flight pins the ring at the anchor's answer")
    func probeExpectationForThePin() throws {
        var learner = believedFloor()
        let issue = try #require(take(&learner))
        #expect(
            learner.probeExpectation(
                for: w,
                asking: issue.size.width,
                axis: \.width
            ) == 720
        )
        // Any other span in flight is honest and unpinned.
        #expect(
            learner.probeExpectation(
                for: w,
                asking: 600,
                axis: \.width
            ) == nil
        )
    }
}
