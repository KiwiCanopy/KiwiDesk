import Foundation
import Testing

@testable import KiwiDeskCore

/// #684: `AXUIElementPerformAction(kAXRaiseAction)` returns before
/// a slow app has performed the raise (measured: the call returns
/// in 0.4-3.8 ms, the window moves 1-20 ms later), so a sequence
/// issued back to back — ~10 ms for eight windows — settles in
/// whatever order the apps get to it.
///
/// The drain's every machine effect is a seam, so the whole loop
/// runs here against a fake WindowServer whose apps perform their
/// raises late on a fake clock: no AX, no `CGWindowList`, no
/// wall-clock sleeping. Nothing in this suite may reach the
/// machine — a test that raises a REAL window would reorder the
/// developer's desktop on every `swift test`.
@Suite("Z-order drain (#684)")
struct ZOrderDrainTests {

    private func ids(_ raw: [UInt32]) -> [WindowID] {
        raw.map(WindowID.init)
    }

    // MARK: - The plan

    @Test("A pile already in order raises nothing")
    func correctOrderPlansNothing() {
        // Raise order is deepest-first, so the desired
        // front-to-back is its reverse.
        #expect(
            ZOrderDrain.plan(
                raiseOrder: ids([4, 3, 2, 1]),
                observed: ids([1, 2, 3, 4])
            ).isEmpty
        )
    }

    /// A reversed pile needs every raise but ONE: the window that
    /// belongs at the very back is already there, and a raise can
    /// only move a window to the front. That is the pathological
    /// case head-on — the deepest window used to be raised first
    /// every time, so a slow app in that slot always surfaced.
    @Test("A reversed pile leaves the deepest window alone")
    func reversedOrderLeavesTheDeepestWindow() {
        #expect(
            ZOrderDrain.plan(
                raiseOrder: ids([4, 3, 2, 1]),
                observed: ids([4, 3, 2, 1])
            ) == ids([3, 2, 1])
        )
    }

    @Test("A single misplaced window is the only raise")
    func oneSwappedPairPlansOneRaise() {
        #expect(
            ZOrderDrain.plan(
                raiseOrder: ids([4, 3, 2, 1]),
                observed: ids([2, 1, 3, 4])
            ) == ids([1])
        )
    }

    /// The measured failure: one window too far forward, the rest
    /// already right. Stacking is by distance from focus, so a
    /// short jump leaves most pairs correct — and a needless raise
    /// is not free, it steals focus for an echo and drags a slow
    /// app back to the front of the pile.
    @Test("Only the windows out of place are raised")
    func oneMisplacedWindowPlansTheStretchAboveIt() {
        // Desired front-to-back 1 > 2 > 3 > 4; window 4 already
        // stands correctly at the back, 3 does not.
        #expect(
            ZOrderDrain.plan(
                raiseOrder: ids([4, 3, 2, 1]),
                observed: ids([1, 2, 4, 3])
            ) == ids([3, 2, 1])
        )
    }

    /// A target the WindowServer does not list on screen —
    /// minimized, or on another space — has no stacking to fix and
    /// no landing that could ever be verified.
    @Test("An off-screen target is dropped from the plan")
    func offScreenTargetIsDropped() {
        #expect(
            ZOrderDrain.plan(
                raiseOrder: ids([9, 3, 2, 1]),
                observed: ids([3, 1, 2])
            ) == ids([2, 1])
        )
        #expect(
            ZOrderDrain.plan(
                raiseOrder: ids([9]),
                observed: ids([1, 2])
            ).isEmpty
        )
    }

    // MARK: - The drain

    /// The bug itself: apps that perform the raise long after the
    /// call returns, and in the wrong order relative to each
    /// other. Waiting for each landing is the only thing that
    /// makes the result the order that was asked for — issue them
    /// back to back on this fake and the clock never advances, so
    /// not one of them lands.
    @Test("Raises land in the order they were issued")
    func lateAppsStillLandInOrder() {
        let server = FakeWindowServer(order: ids([4, 3, 2, 1]))
        // Obsidian-shaped: an order of magnitude slower than the
        // rest, and raised first, which is the case that broke.
        server.latency[WindowID(3)] = 0.08
        let drain = server.drain()
        drain.run(ids([4, 3, 2, 1]))
        #expect(server.stacking() == ids([1, 2, 3, 4]))
        #expect(server.raised == ids([3, 2, 1]))
    }

    /// One wedged app must not stall the windows behind it in the
    /// sequence: its raise is given the per-window limit and then
    /// the drain moves on.
    @Test("A window that never lands is skipped, not waited on")
    func wedgedWindowIsSkipped() {
        let server = FakeWindowServer(order: ids([4, 3, 2, 1]))
        server.latency[WindowID(3)] = .infinity
        let drain = server.drain()
        drain.run(ids([4, 3, 2, 1]))
        #expect(server.raised.contains(WindowID(1)))
        #expect(server.raised.contains(WindowID(2)))
        // The wedged window is retried by the second pass, and the
        // ones that do answer still stand in order among
        // themselves.
        #expect(
            server.stacking().filter { $0 != WindowID(3) }
                == ids([1, 2, 4])
        )
    }

    /// The budget is a total, not a per-window sum: eight windows
    /// at the per-window limit would drain a second, and the
    /// in-flight bracket that holds the mouse warp is up for
    /// exactly as long as the drain. Past it the remaining raises
    /// are issued unverified rather than dropped — unverified is
    /// what every pile did before this drain, while a dropped
    /// raise leaves a window definitely in the wrong place.
    @Test("The total budget still issues every raise")
    func exhaustedBudgetIssuesTheRemainder() {
        let order = ids([8, 7, 6, 5, 4, 3, 2, 1])
        let server = FakeWindowServer(order: order)
        for id in order { server.latency[id] = .infinity }
        let drain = server.drain()
        drain.run(order)
        // Window 8 belongs at the back and is already there, so
        // the plan is the other seven — every one of them issued,
        // none dropped, inside the total budget.
        #expect(Set(server.raised) == Set(order.dropFirst()))
        // A poll interval of slack: the fake clock accumulates in
        // 5 ms steps, so it lands ON the limit, not before it.
        #expect(
            server.clock
                <= ZOrderDrain.totalLimit + ZOrderDrain.pollInterval
        )
    }

    /// A jump landing mid-drain supersedes the sequence: it must
    /// abandon the raises it has left rather than finish them and
    /// fight the newer one.
    @Test("A superseded drain abandons its remaining raises")
    func supersededDrainStops() {
        let server = FakeWindowServer(order: ids([4, 3, 2, 1]))
        server.currentUntilRaises = 2
        let drain = server.drain()
        drain.run(ids([4, 3, 2, 1]))
        #expect(server.raised == ids([3, 2]))
    }
}

/// A WindowServer whose apps perform their raises late, on a fake
/// clock that only advances when the drain sleeps. Deterministic,
/// and it never touches a real window.
private final class FakeWindowServer: @unchecked Sendable {
    /// Front-to-back, the `CGWindowListCopyWindowInfo` order.
    private var order: [WindowID]
    /// Raises accepted but not yet performed, with their due time.
    private var inFlight: [(id: WindowID, due: TimeInterval)] = []

    /// Per-window delay between accepting a raise and performing
    /// it. `.infinity` is an app that never performs it at all.
    var latency: [WindowID: TimeInterval] = [:]
    var defaultLatency: TimeInterval = 0.01
    /// Every raise issued, in order.
    private(set) var raised: [WindowID] = []
    var clock: TimeInterval = 0
    /// How many raises this sequence stays current for, so a test
    /// can supersede it mid-drain.
    var currentUntilRaises = Int.max

    init(order: [WindowID]) {
        self.order = order
    }

    func drain() -> ZOrderDrain {
        ZOrderDrain(
            raise: { [self] id in
                raised.append(id)
                let delay = latency[id] ?? defaultLatency
                guard delay.isFinite else { return }
                inFlight.append((id, clock + delay))
            },
            stacking: { [self] in stacking() },
            now: { [self] in clock },
            sleep: { [self] seconds in clock += seconds },
            isCurrent: { [self] in
                raised.count < currentUntilRaises
            }
        )
    }

    /// Performs everything now due — front-to-back means the
    /// newest raise ends up first — and answers the order.
    func stacking() -> [WindowID] {
        let due = inFlight.filter { $0.due <= clock }
            .sorted { $0.due < $1.due }
        inFlight.removeAll { $0.due <= clock }
        for entry in due {
            order.removeAll { $0 == entry.id }
            order.insert(entry.id, at: 0)
        }
        return order
    }
}
