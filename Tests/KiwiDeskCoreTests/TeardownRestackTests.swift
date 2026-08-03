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
        restack(recorder, raising: [], costing: 0.3).run(circles)
        #expect(
            recorder.runs.map(\.budget) == [1.0, 0.7, 0.4]
        )
    }

    /// Once the clock is spent the restack stops dead rather than
    /// issuing raises it can no longer verify — each of those is a
    /// blocking AX call the budget has no room left to pay for.
    /// The remaining displays are never reached, which is what the
    /// long-standing "stacking left partial" line has always meant.
    @Test("A spent budget stops the restack, and says so")
    func spentBudgetStopsAndLogsPartial() {
        let recorder = Recorder()
        let circles = [
            (display: UInt32(1), order: ids([2, 1])),
            (display: UInt32(2), order: ids([4, 3])),
            (display: UInt32(3), order: ids([6, 5])),
        ]
        restack(recorder, raising: [], costing: 0.6).run(circles)
        // Two groups fit inside the second; the third is not
        // raised at all.
        #expect(recorder.runs.count == 2)
        #expect(
            recorder.logs.last
                == "gatherWindows: raise budget exceeded — "
                + "stacking left partial"
        )
    }

    /// A restack that fits inside its budget says nothing. The
    /// shortfall line is keyed on the clock, so a quiet quit
    /// claiming a shortfall would be the false positive that
    /// matters most.
    @Test("A restack inside its budget logs nothing")
    func restackInsideBudgetIsSilent() {
        let recorder = Recorder()
        let circles = [(display: UInt32(1), order: ids([2, 1]))]
        restack(recorder, raising: ids([2, 1]), costing: 0.1)
            .run(circles)
        #expect(recorder.logs.isEmpty)
    }
}
