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
        meter.settle {
            meter.settle { meter.add(\.parksIssued) }
            meter.add(\.parksIssued)
        }
        let c = meter.snapshot(reset: false).counts
        #expect(c.parksIssued == 4)
        #expect(c.settleParksIssued == 3, "an inner scope ended the outer")
        #expect(c.settlePasses == 3)
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

    /// The switch to 2 parks the first window and shows the
    /// second, and the settle's re-issuing pass sends both again —
    /// the duplicate #1964 measures. The `> 0` clauses pin today's
    /// re-send, not a requirement: #1964's fix moves them.
    @Test("the settle's own pass fills the share")
    func settleFillsTheShare() async throws {
        guard NSScreen.main != nil else { return }
        let (core, meter) = makeCore()
        core.execute("focus_space", args: [.string("2")])
        let switched = meter.snapshot(reset: false).counts
        #expect(switched.settleParksIssued == 0)
        #expect(switched.settleFramesIssued == 0)
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
    }

    @Test("the report carries every settle share under its own key")
    func reportCarriesTheShare() {
        let meter = WorkMeter(now: { 0 })
        let keys: [(WritableKeyPath<WorkMeter.Counts, Int>, String)] = [
            (\.framesIssued, "settle_frames_issued"),
            (\.framesSkipped, "settle_frames_skipped"),
            (\.parksIssued, "settle_parks_issued"),
            (\.parksSkipped, "settle_parks_skipped"),
            (\.passesHeld, "settle_passes_held"),
            (\.passesMerged, "settle_passes_merged"),
        ]
        meter.settle {
            for (n, (key, _)) in keys.enumerated() {
                meter.add(key, n + 1)
            }
        }
        guard case .object(let r) = meter.report(reset: false) else {
            Issue.record("report is not an object")
            return
        }
        for (n, (_, name)) in keys.enumerated() {
            #expect(r[name] == .number(Double(n + 1)), "\(name)")
        }
        #expect(r["settle_passes"] == .number(1))
    }

    /// A settle the motion gate holds issues nothing inside its
    /// scope; it is counted as held so the run can tell a skewed
    /// share from a settle that sent nothing.
    @Test("a held settle is counted as held, its work as nobody's")
    func heldSettleIsCounted() async throws {
        guard NSScreen.main != nil else { return }
        let (core, meter) = makeCore()
        core.tiler.motionGate.schedule = { _, _ in }
        core.execute("focus_space", args: [.string("2")])
        let switched = meter.snapshot(reset: false).counts
        core.tiler.motionGate.quiescence.sinceMouseMoved = { 0 }
        await core.deferred.task(for: .spaceSettle)?.value
        let c = meter.snapshot(reset: false).counts
        #expect(c.settlePasses == 1)
        #expect(c.settlePassesHeld == 1)
        #expect(c.settlePassesMerged == 0)
        #expect(c.settleParksIssued == 0)
        #expect(c.parksIssued == switched.parksIssued)
    }

    /// A settle that pays a held debt runs that debt's work too, so
    /// it is counted as merged.
    @Test("a settle that pays a held debt is counted as merged")
    func mergedSettleIsCounted() async throws {
        guard NSScreen.main != nil else { return }
        let (core, meter) = makeCore()
        let quiet = core.tiler.motionGate.quiescence
        core.tiler.motionGate.schedule = { _, _ in }
        core.execute("focus_space", args: [.string("2")])
        quiet.sinceMouseMoved = { 0 }
        core.retile()
        quiet.sinceMouseMoved = { .infinity }
        await core.deferred.task(for: .spaceSettle)?.value
        let c = meter.snapshot(reset: false).counts
        #expect(c.passesHeld == 1)
        #expect(c.settlePassesHeld == 0)
        #expect(c.settlePassesMerged == 1)
        #expect(core.tiler.motionGate.owed == nil)
    }
}
