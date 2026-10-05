import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The Space switch's settle pass counts its own share of the parks
/// and frames (#1964), so a measurement can tell what the settle
/// re-sends from what the switch sent. Driven through the real
/// `focus_space` and its `DeferredTasks` slot; display pinned
/// (#531), the meter injected.
@Suite("Settle work share (#1964)", .serialized)
@MainActor
struct SettleWorkShareTests {
    @Test("only work inside the settle scope counts as its share")
    func shareIsScoped() {
        let meter = WorkMeter(now: { 0 })
        meter.add(\.parksIssued)
        meter.settle {
            meter.add(\.parksIssued)
            meter.add(\.framesIssued)
            meter.add(\.parksSkipped)
        }
        meter.add(\.framesSkipped)
        let c = meter.snapshot(reset: false).counts
        #expect(c.parksIssued == 2)
        #expect(c.settleParksIssued == 1)
        #expect(c.settleFramesIssued == 1)
        #expect(c.settleParksSkipped == 1)
        #expect(c.framesSkipped == 1)
        #expect(c.settleFramesSkipped == 0)
    }

    /// One window in Space 1, one in Space 2, Space 1 shown.
    private func makeCore() -> (KiwiCore, WorkMeter) {
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        core.tiler.animation.isEnabled = false
        for (id, space) in [(WindowID(1), 1), (WindowID(2), 2)] {
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

    /// The app's answer to the switch: each window reports the
    /// frame it was last sent, and the echo retires the instant
    /// target as `KiwiCore+Events` does. The clocks are frozen by
    /// `makeTestCore` (#1456), so the sets stay inside the grace.
    private func echo(_ core: KiwiCore) throws {
        for id in [WindowID(1), WindowID(2)] {
            let frame = try #require(core.tiler.placements.recent(id))
            core.state.apply(.windowResized(id, frame))
            core.tiler.clearInstantTarget(id)
        }
    }

    /// The switch to 2 parks the first window and shows the
    /// second, and the settle's re-issuing pass sends both again —
    /// the duplicate #1964 measures.
    @Test("the settle's own pass fills the share", arguments: [false, true])
    func settleFillsTheShare(echoed: Bool) async throws {
        guard NSScreen.main != nil else { return }
        let (core, meter) = makeCore()
        core.execute("focus_space", args: [.string("2")])
        let switched = meter.snapshot(reset: false).counts
        #expect(switched.settleParksIssued == 0)
        #expect(switched.settleFramesIssued == 0)
        if echoed { try echo(core) }
        let settle = core.deferred.task(for: .spaceSettle)
        #expect(settle != nil, "the switch scheduled no settle")
        await settle?.value
        let c = meter.snapshot(reset: false).counts
        #expect(
            c.settleParksIssued
                == c.parksIssued - switched.parksIssued
        )
        #expect(
            c.settleFramesIssued
                == c.framesIssued - switched.framesIssued
        )
        #expect(c.settleParksIssued > 0)
        #expect(c.settleFramesIssued > 0)
        // Answered, every re-send was already confirmed; unanswered,
        // none was.
        #expect(
            c.settleParksConfirmed
                == (echoed ? c.settleParksIssued : 0)
        )
        #expect(
            c.settleFramesConfirmed
                == (echoed ? c.settleFramesIssued : 0)
        )
    }
}
