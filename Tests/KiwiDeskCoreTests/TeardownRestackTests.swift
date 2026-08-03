import Foundation
import Testing

@testable import KiwiDeskCore

/// The four decisions the quit-grid restack gets exactly one shot
/// at (#688). They were guarded only by source-text needles over
/// `restackForTeardown`'s body until `TeardownRestack` put them
/// behind seams; a scan reds on renaming a local and passes on
/// `budget * 2` (architect review, 2026-08-03), so these assert the
/// behavior instead and `ZOrderSequenceWiringTests` is left with
/// the one thing a unit test cannot see — that production binds the
/// real machine to those seams.
///
/// No AX, no WindowServer, no wall clock: the drain seam hands back
/// a recorder, so a "raise" here is an entry in an array.
@MainActor
@Suite("Teardown restack (#688)")
struct TeardownRestackTests {

    private func ids(_ raw: [UInt32]) -> [WindowID] {
        raw.map(WindowID.init)
    }

    /// Records what each display group was asked to do.
    private final class Recorder: @unchecked Sendable {
        var clock: TimeInterval = 0
        var trusted = true
        var unbeatable: WindowID?
        var logs: [String] = []
        /// Per group: the order handed to the drain and the budget
        /// it was given.
        var runs: [(order: [WindowID], budget: TimeInterval)] = []
    }

    /// A drain seam that advances the fake clock and reports a
    /// fixed number of raises, so budget exhaustion is reachable
    /// without a WindowServer.
    private func restack(
        _ recorder: Recorder,
        raising raised: [WindowID] = [],
        costing cost: TimeInterval = 0
    ) -> TeardownRestack {
        TeardownRestack(
            isTrusted: { recorder.trusted },
            unbeatable: { recorder.unbeatable },
            now: { recorder.clock },
            drain: { order, policy in
                recorder.runs.append((order, policy.budget))
                recorder.clock += cost
                return ZOrderDrain(
                    raise: { _ in },
                    stacking: { raised },
                    now: { recorder.clock },
                    // Advance the fake clock, exactly as
                    // `ZOrderDrainFake` does. A no-op sleep against
                    // a clock nothing moves makes `awaitLanding`'s
                    // `now() < limit` permanently true — an
                    // infinite spin, not a slow test (hit while
                    // writing this suite).
                    sleep: { recorder.clock += $0 },
                    isCurrent: { true },
                    floor: [],
                    policy: policy
                )
            },
            log: { recorder.logs.append($0) },
            policy: .teardown
        )
    }

    // MARK: - The Accessibility gate

    /// `stop()` also runs on a permission revoke, where no raise
    /// can land but the WindowServer read keeps answering — so the
    /// drain is never satisfied and sleeps away the whole budget on
    /// the main actor. The gate is that regression's fix, and
    /// deleting it used to leave all 2424 tests green.
    @Test("An untrusted process raises nothing at all")
    func noGrantMeansNoRestack() {
        let recorder = Recorder()
        recorder.trusted = false
        restack(recorder).run([(display: UInt32(1), order: ids([3, 2, 1]))])
        #expect(recorder.runs.isEmpty)
        #expect(
            recorder.logs == [
                "gatherWindows: no Accessibility permission — "
                    + "skipping the raise circle"
            ]
        )
    }

    // MARK: - The window no raise can beat

    /// Dropped from the circle rather than ordered around: a quiet
    /// raise cannot lift anything above the frontmost app's key
    /// window, so leaving it in costs every window above it a whole
    /// `landingLimit` — `ZOrderTeardownDrainTests` prices that.
    @Test("The unbeatable window is dropped from the circle")
    func unbeatableWindowIsDropped() {
        let recorder = Recorder()
        recorder.unbeatable = WindowID(2)
        let circles = [(display: UInt32(1), order: ids([3, 2, 1]))]
        restack(recorder).run(circles)
        #expect(recorder.runs.map(\.order) == [ids([3, 1])])
    }

    /// Nil is the ordinary answer — no frontmost app, an ignored
    /// panel (#21), or an AX read that did not come back — and it
    /// must leave the circle whole rather than empty it.
    @Test("No unbeatable window leaves the circle intact")
    func noUnbeatableWindowKeepsEveryone() {
        let recorder = Recorder()
        let circles = [(display: UInt32(1), order: ids([3, 2, 1]))]
        restack(recorder).run(circles)
        #expect(recorder.runs.map(\.order) == [ids([3, 2, 1])])
    }

    /// A group whose every member is the dropped window has nothing
    /// left to raise, and must not reach the drain — a drain over
    /// an empty order would verify a landing against nothing.
    @Test("A group emptied by the drop is skipped")
    func groupEmptiedByTheDropIsSkipped() {
        let recorder = Recorder()
        recorder.unbeatable = WindowID(1)
        let circles = [
            (display: UInt32(1), order: ids([1])),
            (display: UInt32(2), order: ids([5, 4])),
        ]
        restack(recorder).run(circles)
        #expect(recorder.runs.map(\.order) == [ids([5, 4])])
    }

    // MARK: - The wall clock

    /// The shipped whole-quit budget, read rather than restated:
    /// every expectation below is derived from it, so moving the
    /// policy moves the fixture instead of reddening it for a
    /// reason that has nothing to do with the invariant
    /// (guard-prover, 2026-08-03).
    private var budget: TimeInterval {
        ZOrderDrain.Policy.teardown.budget
    }

    /// Each display gets what is LEFT of the whole-quit budget, not
    /// a fresh copy of it — otherwise three displays could spend
    /// three seconds on a quit that promised one.
    @Test("Each display group is given the remaining budget")
    func eachGroupGetsWhatIsLeft() {
        let recorder = Recorder()
        let circles = [
            (display: UInt32(1), order: ids([2, 1])),
            (display: UInt32(2), order: ids([4, 3])),
            (display: UInt32(3), order: ids([6, 5])),
        ]
        let cost = budget / 4
        restack(recorder, raising: [], costing: cost).run(circles)
        #expect(
            recorder.runs.map(\.budget)
                == [budget, budget - cost, budget - 2 * cost]
        )
    }

    /// Once the clock is spent the restack STOPS rather than
    /// skipping the group and carrying on — each further raise is a
    /// blocking AX call the budget has no room left to pay for.
    ///
    /// The over-budget group is deliberately not the last one, and
    /// the log COUNT is asserted: with the group last, `return` and
    /// `continue` are indistinguishable, and that is how the first
    /// draft of this test passed against a `continue` (guard-prover,
    /// 2026-08-03). A `continue` would visit displays 3 and 4 too
    /// and log the partial line three times.
    @Test("A spent budget stops the restack, and says so once")
    func spentBudgetStopsAndLogsPartial() {
        let recorder = Recorder()
        let circles = [
            (display: UInt32(1), order: ids([2, 1])),
            (display: UInt32(2), order: ids([4, 3])),
            (display: UInt32(3), order: ids([6, 5])),
            (display: UInt32(4), order: ids([8, 7])),
        ]
        // Two groups exhaust it, so the loop must end at the third.
        restack(recorder, raising: [], costing: budget * 0.6)
            .run(circles)
        #expect(recorder.runs.count == 2)
        let partial =
            "gatherWindows: raise budget exceeded — "
            + "stacking left partial"
        // Exactly once, and last. Group 2 legitimately logs its own
        // shortfall before this, so the whole log is not the
        // discriminator — the COUNT is: a `continue` would reach
        // displays 3 and 4 and emit this line three times.
        #expect(recorder.logs.filter { $0 == partial }.count == 1)
        #expect(recorder.logs.last == partial)
    }

    /// A restack that fits inside its budget says nothing.
    @Test("A restack inside its budget logs nothing")
    func restackInsideBudgetIsSilent() {
        let recorder = Recorder()
        let circles = [(display: UInt32(1), order: ids([2, 1]))]
        restack(recorder, raising: ids([2, 1]), costing: budget / 10)
            .run(circles)
        // Both halves: silent, and it really did the work. Without
        // the second, an empty `run` passes this test
        // (guard-prover, 2026-08-03).
        #expect(recorder.logs.isEmpty)
        #expect(recorder.runs.count == 1)
    }

    /// The false positive `!raised.isEmpty` exists to remove, with
    /// a fixture that actually reaches it.
    ///
    /// An already-correct group plans nothing, so the drain returns
    /// having raised none of the circle — after a single ~0.4 ms
    /// read. If that read is what tips the clock past the deadline,
    /// the clock arm alone would report a shortfall on a group that
    /// had nothing to do. Modelled by letting the group's stacking
    /// already match its circle while the read spends the whole
    /// budget.
    ///
    /// The suite's other silent test never reaches this term — its
    /// drain does raise, so the clock arm decides and dropping
    /// `!raised.isEmpty` left the whole suite green (guard-prover,
    /// 2026-08-03).
    @Test("A group with nothing to do claims no shortfall")
    func alreadyCorrectGroupClaimsNoShortfall() {
        let recorder = Recorder()
        let circle = ids([2, 1])
        // Stacking already equals the circle's desired front-to-back
        // order, so `plan` is empty and `run` raises nothing.
        restack(recorder, raising: ids([1, 2]), costing: budget)
            .run([(display: UInt32(1), order: circle)])
        #expect(recorder.runs.count == 1)
        #expect(recorder.logs.isEmpty)
    }
}
