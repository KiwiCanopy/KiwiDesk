import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// **The work a Space switch and a retile do, counted** (#1884):
/// a change that silently re-parks every hidden window or retiles
/// more per event reds here. Counts, never times (#344); each pin
/// is derived from the fixture's shape where it is asserted. A
/// frame or park counted here is one engine ASK, the unit behind
/// the AX writes an injected meter does not count.
/// Display pinned (#531), animation off, the ask ledger's clock
/// frozen by `makeTestCore` (#1456).
@Suite("Switch and retile work counts (#1884)", .serialized)
@MainActor
struct SwitchWorkCountTests {
    private let shown = (1...3).map { WindowID($0) }
    private let incoming = (4...5).map { WindowID($0) }
    private let hidden = (6...9).map { WindowID($0) }

    private func makeCore() -> (KiwiCore, WorkMeter) {
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        core.tiler.animation.isEnabled = false
        let spaces = [(shown, 1), (incoming, 2), (hidden, 3)]
        for (ids, space) in spaces {
            for id in ids {
                core.state.apply(
                    .windowCreated(
                        ManagedWindow(id: id, pid: 1, appName: "A")
                    )
                )
                core.state.workspaces.add(id, to: SpaceID(space))
            }
        }
        core.retile()
        let meter = WorkMeter(now: { 0 })
        core.tiler.meter = meter
        return (core, meter)
    }

    private func echo(_ core: KiwiCore) throws {
        for id in shown + incoming + hidden {
            let frame = try #require(core.tiler.placements.recent(id))
            core.state.apply(.windowResized(id, frame))
        }
    }

    /// Re-echoes every issued frame and zeroes the meter.
    private func settle(_ core: KiwiCore, _ meter: WorkMeter) throws {
        try echo(core)
        _ = meter.snapshot(reset: true)
    }

    @Test("A retile with nothing to move issues nothing")
    func noOpRetile() throws {
        guard NSScreen.main != nil else { return }
        let (core, meter) = makeCore()
        try settle(core, meter)
        core.retile()
        let c = meter.snapshot(reset: false).counts
        // Every frame already landed: the shown windows skip, the
        // hidden ones take the "already parked" check.
        #expect(c.retiles == 1)
        #expect(c.framesIssued == 0)
        #expect(c.framesSkipped == shown.count)
        #expect(c.parksIssued == 0)
        #expect(c.parksSkipped == incoming.count + hidden.count)
        #expect(c.barRenders == 1)
    }

    @Test("A switch parks what it leaves and frames what it shows")
    func switchWork() throws {
        guard NSScreen.main != nil else { return }
        let (core, meter) = makeCore()
        try settle(core, meter)
        core.execute("focus_space", args: [.string("2")])
        let c = meter.snapshot(reset: false).counts
        // One re-issuing pass, one bar render; the long-hidden
        // Space 3 is checked, never re-parked (#1508).
        #expect(c.spaceSwitches == 1)
        #expect(c.retiles == 1)
        #expect(c.reissuePasses == 1)
        #expect(c.barRenders == 1)
        #expect(c.parksIssued == shown.count)
        #expect(c.parksSkipped == hidden.count)
        #expect(c.framesIssued == incoming.count)
        #expect(c.framesSkipped == 0)
    }

    @Test("The switch's settle re-sends what got no echo")
    func settleUnechoed() throws {
        guard NSScreen.main != nil else { return }
        let (core, meter) = makeCore()
        try settle(core, meter)
        core.execute("focus_space", args: [.string("2")])
        _ = meter.snapshot(reset: true)
        // The settle's pass, called by hand rather than through
        // `scheduleSpaceSettle`: a change to that pass's shape
        // leaves these pins green.
        core.retile(animated: false, pass: .reissue)
        let c = meter.snapshot(reset: false).counts
        // No answer yet: every park and frame is re-sent.
        #expect(c.parksIssued == shown.count)
        #expect(c.framesIssued == incoming.count)
    }

    @Test("The switch's settle re-sends what an echo confirmed")
    func settleEchoed() throws {
        guard NSScreen.main != nil else { return }
        let (core, meter) = makeCore()
        core.execute("focus_space", args: [.string("2")])
        // Through the event arm, so each echo retires its instant
        // target as a real one does — #1964's reading of
        // "answered"; the applier's clock is frozen (#1456).
        for id in shown + incoming + hidden {
            let frame = try #require(core.tiler.placements.recent(id))
            core.handle(.windowResized(id, frame))
        }
        // The fixture reaches "answered": every park retired.
        for id in shown {
            #expect(core.tiler.recentInstantTarget(id) == nil)
        }
        _ = meter.snapshot(reset: true)
        core.retile(animated: false, pass: .reissue)
        let c = meter.snapshot(reset: false).counts
        // Today's behaviour, which #1964 asks whether to keep: a
        // fix that skips a confirmed park re-baselines this.
        #expect(c.parksIssued == shown.count)
        #expect(c.framesIssued == incoming.count)
    }

    @Test("A burst of arrivals takes one retile per event")
    func arrivalBurst() throws {
        guard NSScreen.main != nil else { return }
        let (core, meter) = makeCore()
        core.execute("focus_space", args: [.string("2")])
        try settle(core, meter)
        let arrivals: [UInt32] = [10, 11, 12]
        for n in arrivals {
            core.handle(
                .windowCreated(
                    ManagedWindow(id: WindowID(n), pid: 1, appName: "A")
                )
            )
        }
        let c = meter.snapshot(reset: false).counts
        // #1887 closed with one pass per event; each pass weighs
        // every tiled member (2 + k after the k-th arrival) and
        // checks every parked one.
        let parked = shown.count + hidden.count
        #expect(c.events == arrivals.count)
        #expect(c.retiles == arrivals.count)
        let weighed = (1...arrivals.count).reduce(0) {
            $0 + incoming.count + $1
        }
        #expect(c.framesIssued + c.framesSkipped == weighed)
        #expect(c.framesIssued >= arrivals.count)
        #expect(c.parksIssued == 0)
        #expect(c.parksSkipped == parked * arrivals.count)
    }
}
