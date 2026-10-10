import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A Desktop switch's re-sync folds its windows' departures into
/// ONE pass. Each departure used to retile, render the bars and
/// sync the rings, so leaving a Desktop of eleven apps ran 17
/// passes inside the switch's own main turn, and the ring stood on
/// the window that left until they ended (device probe,
/// 2026-10-10). Passes read off an injected meter; display pinned
/// (#531).
@Suite("A Desktop switch's re-sync is one pass", .serialized)
@MainActor
struct SwitchResyncFoldTests {
    private let ids = [WindowID(1), WindowID(2), WindowID(3)]

    private func makeCore() -> (KiwiCore, WorkMeter) {
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        core.tiler.animation.isEnabled = false
        for id in ids {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(id: id, pid: 1, appName: "A")
                )
            )
            core.state.workspaces.add(id, to: SpaceID(1))
        }
        core.retile()
        let meter = WorkMeter(now: { 0 })
        core.tiler.meter = meter
        return (core, meter)
    }

    private func departAll(_ core: KiwiCore) {
        for id in ids {
            core.handle(.windowDestroyed(id, wasMinimized: false))
        }
    }

    @Test("Departures inside the fold run one pass, after them")
    func foldRunsOnePass() {
        let (core, meter) = makeCore()
        var passesDuring = -1
        core.foldingSwitchResync {
            departAll(core)
            passesDuring = meter.snapshot(reset: false).counts.retiles
        }
        #expect(passesDuring == 0)
        #expect(meter.snapshot(reset: false).counts.retiles == 1)
        #expect(ids.allSatisfy { core.state.windows[$0] == nil })
    }

    @Test("Outside the fold each departure still retiles")
    func unfoldedRetilesPerEvent() {
        let (core, meter) = makeCore()
        departAll(core)
        #expect(
            meter.snapshot(reset: false).counts.retiles == ids.count
        )
    }

    @Test("A fold with no structural event runs no pass")
    func emptyFoldRunsNothing() {
        let (core, meter) = makeCore()
        core.foldingSwitchResync {}
        #expect(meter.snapshot(reset: false).counts.retiles == 0)
    }

    @Test("A nested fold folds into the outer one")
    func nestedFoldJoinsTheOuter() {
        let (core, meter) = makeCore()
        core.foldingSwitchResync {
            core.foldingSwitchResync { departAll(core) }
            #expect(meter.snapshot(reset: false).counts.retiles == 0)
        }
        #expect(meter.snapshot(reset: false).counts.retiles == 1)
    }

    /// The event loop's seam is the one the switch handler takes;
    /// bootstrap wires it to the fold, and unwired it folds
    /// nothing.
    @Test("The event loop's seam reaches the fold")
    func eventLoopSeamIsWired() {
        let (core, meter) = makeCore()
        core.eventLoop.foldsSwitchResync { departAll(core) }
        #expect(meter.snapshot(reset: false).counts.retiles == 1)
    }
}
