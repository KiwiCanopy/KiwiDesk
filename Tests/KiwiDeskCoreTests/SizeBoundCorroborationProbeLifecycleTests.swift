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

    @Test("A performed probe is decided by the settled read alone")
    func performedProbeIsDecidedSettled() throws {
        // The window PERFORMED the probe's ask — a grid app
        // landing inside the tolerance, or a lifted floor — and
        // now holds a size no layout drew, which the compliance
        // sweep's "nothing to place" cannot see. The settled read
        // says so; a raw echo retires nothing, since the emulator
        // performs an ask for ~0.4 s and snaps back (#1049).
        var settled = believedFloor()
        let issue = try #require(take(&settled))
        settled.recordAsk(w, size: issue.size)
        let verdict = settled.observeAnswer(
            w,
            currentSize: issue.size,
            settledRead: true
        )
        #expect(verdict.performedProbe)
        #expect(!verdict.confirmed)
        // Closed: the anchor was swept, and the ask stays probed.
        let again = take(&settled)
        #expect(again == nil)

        // The raw echo: nothing retired, and the settle probe
        // stays wanted for a compliance at the probe's ask.
        var raw = believedFloor()
        let rawIssue = try #require(take(&raw))
        raw.recordAsk(w, size: rawIssue.size)
        let echo = raw.observeAnswer(
            w,
            currentSize: rawIssue.size,
            settledRead: false
        )
        #expect(!echo.performedProbe)
        #expect(
            raw.probePending(
                w,
                asking: rawIssue.size.width,
                axis: \.width
            )
        )
        #expect(raw.wantsProbe(w, currentSize: rawIssue.size))
        // …so the snap-back pair-promotes and corroborates.
        let revoke = raw.observeAnswer(
            w,
            currentSize: held,
            settledRead: false
        )
        #expect(revoke.confirmed)
        #expect(raw.bound(for: w)?.minWidth == 720)

        // An ordinary compliance performs no probe and wants no
        // read.
        var plain = believedFloor()
        let other = CGSize(width: 900, height: 800)
        plain.recordAsk(w, size: other)
        let ordinary = plain.observeAnswer(
            w,
            currentSize: other,
            settledRead: true
        )
        #expect(!ordinary.performedProbe)
        #expect(!plain.wantsProbe(w, currentSize: other))
    }

    @Test("Alternating anchors keep their one probe each")
    func alternatingAnchorsKeepTheirProbes() throws {
        // Two layouts alternate their asks on one axis (the
        // per-ask ladder's own case): each anchor's probe, once
        // retired, stays retired through the other's — the
        // probed list is per anchor, not one record per axis,
        // which the second anchor's probe would have replaced.
        // The first anchor's probe answers a few points off, so
        // its axis stays uncorroborated and only the list can
        // refuse the re-arm.
        var learner = believedFloor()
        let first = try #require(take(&learner))
        let off = CGSize(width: 705, height: 800)
        learner.recordAsk(w, size: first.size, settledFrom: first.baseline)
        learner.observe(w, currentSize: off, settledRead: true)
        let reissued = try #require(take(&learner))
        learner.recordAsk(w, size: reissued.size)
        learner.observe(w, currentSize: off, settledRead: true)
        #expect(learner.bound(for: w)?.minWidth == nil)
        // A settled compliance below the floor sweeps the anchor.
        let performed = CGSize(width: 480, height: 800)
        learner.recordAsk(w, size: performed)
        learner.observe(w, currentSize: performed, settledRead: true)
        #expect(learner.bound(for: w) == nil)
        // The second anchor: a ceiling at 900 answered 800, probed
        // and corroborated.
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
        learner.recordAsk(w, size: second.size, settledFrom: second.baseline)
        learner.observe(w, currentSize: capped, settledRead: true)
        #expect(learner.bound(for: w)?.maxWidth == 800)
        // Back to the first anchor, re-confirmed after its sweep:
        // no second probe for it.
        learner.recordAsk(w, size: ask, settledFrom: held)
        learner.observe(w, currentSize: held, settledRead: true)
        let entries = learner.bound(for: w)?.width ?? []
        #expect(entries.contains { $0.asked == 500 })
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
