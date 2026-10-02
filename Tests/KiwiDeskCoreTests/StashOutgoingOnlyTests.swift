import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A Space switch forces the park of only the Space it leaves,
/// on its own pass and its settle's (#1508): a window parked
/// longer than that takes the "already parked" check, or every
/// switch re-parks every hidden window, ~6 AX calls each. Driven
/// through the real `focus_space`, the parks read off an
/// injected meter; the ask ledger's clock is frozen by
/// `makeTestCore` (#1456). Display pinned (#531).
@Suite("Switch re-parks only the outgoing Space (#1508)", .serialized)
@MainActor
struct StashOutgoingOnlyTests {
    private let w1 = WindowID(1)
    private let w2 = WindowID(2)
    private let w3 = WindowID(3)

    /// One window in each of Spaces 1, 2 and 3, Space 1 shown
    /// and the other two parked by the first pass.
    private func makeCore() -> (KiwiCore, WorkMeter) {
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        core.tiler.animation.isEnabled = false
        for (id, space) in [(w1, 1), (w2, 2), (w3, 3)] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(id: id, pid: 1, appName: "A")
                )
            )
            core.state.workspaces.add(id, to: SpaceID(space))
        }
        core.retile()
        let meter = WorkMeter(now: { 0 })
        core.tiler.meter = meter
        return (core, meter)
    }

    /// The AX echo of each window's last issued frame. The
    /// ledger's clock is frozen by `makeTestCore` (#1456).
    private func echo(_ core: KiwiCore, _ ids: [WindowID]) throws {
        for id in ids {
            let frame = try #require(core.tiler.placements.recent(id))
            core.state.apply(.windowResized(id, frame))
        }
    }

    @Test("A Space parked before the switch is not re-parked")
    func longParkedSpaceTakesTheCheck() throws {
        guard NSScreen.main != nil else { return }
        let (core, meter) = makeCore()
        try echo(core, [w1, w2, w3])
        _ = meter.snapshot(reset: true)
        core.execute("focus_space", args: [.string("2")])
        let c = meter.snapshot(reset: false).counts
        // w1 leaves view and parks; w3 already sits parked.
        #expect(c.parksIssued == 1)
        #expect(c.parksSkipped == 1)
    }

    /// Space 2 is shown and left before its windows' echoes
    /// land, and the instant ledger has let the show go — in
    /// production a self-echo clears it whatever frame it
    /// carries: the state frame still reads the first park's
    /// corner, so only a force sends the park again.
    private func leaveSpaceTwoUnechoed(_ core: KiwiCore) throws {
        try echo(core, [w1, w2, w3])
        core.execute("focus_space", args: [.string("2")])
        core.tiler.clearInstantTarget(w2)
    }

    @Test("The Space left is forced by the switch and its settle")
    func departureForcedTwice() throws {
        guard NSScreen.main != nil else { return }
        let (core, meter) = makeCore()
        try leaveSpaceTwoUnechoed(core)
        var parks: [(Int, Int)] = []
        for step in 0..<3 {
            _ = meter.snapshot(reset: true)
            if step == 0 {
                core.execute("focus_space", args: [.string("1")])
            } else {
                // The settle's pass (`scheduleSpaceSettle`).
                core.retile(animated: false, pass: .reissue)
            }
            // Isolates the force from the commanded net.
            core.tiler.clearInstantTarget(w2)
            let c = meter.snapshot(reset: false).counts
            parks.append((c.parksIssued, c.parksSkipped))
        }
        // w2 forced over its stale corner by the switch and the
        // settle, then checked; w3 checked throughout.
        #expect(parks.map(\.0) == [1, 1, 0])
        #expect(parks.map(\.1) == [1, 1, 2])
    }

    @Test("An event pass seeing the departure first leaves it owed")
    func eventPassKeepsTheDeparture() throws {
        guard NSScreen.main != nil else { return }
        let (core, meter) = makeCore()
        try leaveSpaceTwoUnechoed(core)
        core.state.workspaces.activate(SpaceID(1))
        _ = meter.snapshot(reset: true)
        core.retile()
        var c = meter.snapshot(reset: true).counts
        #expect(c.parksIssued == 0)
        core.retile(animated: false, pass: .reissue)
        c = meter.snapshot(reset: false).counts
        #expect(c.parksIssued == 1)
    }

    @Test("An unanswered ask outranks a corner the state still reads")
    func pendingAskIsNotParked() throws {
        // A move into a hidden Space, a renumbered held Space:
        // no departure is owed, but the window was last sent
        // somewhere other than the corner.
        guard NSScreen.main != nil else { return }
        let (core, meter) = makeCore()
        try echo(core, [w1, w2, w3])
        core.execute("focus_space", args: [.string("2")])
        core.state.workspaces.activate(SpaceID(1))
        _ = meter.snapshot(reset: true)
        core.retile()
        let c = meter.snapshot(reset: false).counts
        #expect(c.parksIssued == 1)
        #expect(c.parksSkipped == 1)
    }

    @Test("A slide away outranks an older instant park")
    func animationOutranksInstantPark() {
        // An instant park, then an animated slide-in inside the
        // echo grace: the animation is the newer ask, and the
        // instant ledger still holds the corner.
        guard let screen = NSScreen.main, screen.kiwiDisplay != nil
        else { return }
        let engine = TilingEngine()
        let meter = WorkMeter(now: { 0 })
        engine.meter = meter
        engine.applier.clock = { 0 }
        let bounds = CGRect(x: 0, y: 25, width: 1728, height: 1092)
        let slot = CGRect(x: 100, y: 100, width: 800, height: 600)
        let corner = TilingEngine.stashFrame(
            slot,
            in: bounds,
            corner: .bottomRight
        )
        let id = WindowID(1)
        engine.setFrame(id, corner)
        engine.applyFrame(id, from: corner, to: slot, animated: true)
        engine.stash(
            ManagedWindow(id: id, pid: 100, appName: "A", frame: corner),
            in: bounds,
            corner: .bottomRight,
            force: false,
            capturesOriginal: false
        )
        let c = meter.snapshot(reset: false).counts
        engine.animation.cancelAll(snapToTargets: false)
        #expect(c.parksIssued == 1)
        #expect(c.parksSkipped == 0)
    }

    @Test("A park macOS lifted off its line counts as parked")
    func liftedParkIsParked() {
        // Measured 4 pt on Finder (`looksStashed`, #1352): a
        // lift inside the visibility floor is the park landing,
        // and one past it is a window somewhere else.
        let engine = TilingEngine()
        let meter = WorkMeter(now: { 0 })
        engine.meter = meter
        let bounds = CGRect(x: 0, y: 25, width: 1728, height: 1092)
        let size = CGRect(x: 0, y: 0, width: 1354, height: 945)
        let corner = TilingEngine.stashFrame(
            size,
            in: bounds,
            corner: .bottomRight
        )
        let floor = WindowServerFacts.visibilityFloor
        for lift in [CGFloat(4), floor, floor + 4] {
            let window = ManagedWindow(
                id: WindowID(1),
                pid: 100,
                appName: "Finder",
                frame: corner.offsetBy(dx: 0, dy: -lift)
            )
            engine.stash(
                window,
                in: bounds,
                corner: .bottomRight,
                force: false,
                capturesOriginal: false
            )
        }
        let c = meter.snapshot(reset: false).counts
        #expect(c.parksSkipped == 2)
        #expect(c.parksIssued == 1)
    }
}
