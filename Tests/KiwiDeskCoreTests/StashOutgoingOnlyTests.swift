import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A Space switch forces the park of only the Space it leaves
/// (#1508): a window parked longer than that takes the "already
/// parked" check, or every switch re-parks every hidden window,
/// ~6 AX calls each. Driven through the real `focus_space`, the
/// parks read off an injected meter. Display pinned (#531).
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

    @Test("The outgoing Space is re-parked over an echo-lagged corner")
    func outgoingSpaceIsForced() throws {
        // Space 2 is shown and left before its windows' echoes
        // land: the state frame still reads the corner from the
        // first park, so only the force sends the park again.
        guard NSScreen.main != nil else { return }
        let (core, meter) = makeCore()
        try echo(core, [w1, w2, w3])
        core.execute("focus_space", args: [.string("2")])
        _ = meter.snapshot(reset: true)
        core.execute("focus_space", args: [.string("1")])
        let c = meter.snapshot(reset: false).counts
        // w2 forced over its stale corner; w3 still skipped.
        #expect(c.parksIssued == 1)
        #expect(c.parksSkipped == 1)
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
