import Foundation
import Testing

@testable import KiwiDeskCore

/// **The bars wait for a Desktop switch's arrivals** (#2347): the
/// handler's own refresh would draw the arriving Space before its
/// windows are tracked, so a refresh asked while the batch is
/// pending is owed, and the batch's fold pays it once. Counted on
/// an injected meter, never timed (#344).
@Suite("Switch reconcile holds the bars (#2347)")
@MainActor
struct SwitchReconcileBarsTests {
    @Test("a bar refresh during the batch is owed, then paid once")
    func barsWaitForTheFold() {
        let core = makeTestCore()
        let meter = WorkMeter(now: { 0 })
        core.tiler.meter = meter
        core.eventLoop.beginSwitchReconcile()
        core.updateBars()
        core.updateBars()
        #expect(meter.snapshot(reset: false).counts.barRenders == 0)
        #expect(core.eventLoop.switchReads.barsOwed)
        // Nothing observed: the batch applies at once, and its
        // fold pays the held refresh.
        core.eventLoop.requestSwitchReads()
        #expect(meter.snapshot(reset: false).counts.barRenders == 1)
        #expect(!core.eventLoop.switchReads.barsOwed)
    }

    @Test("no batch pending: a refresh draws at once")
    func barsDrawWithoutABatch() {
        let core = makeTestCore()
        let meter = WorkMeter(now: { 0 })
        core.tiler.meter = meter
        core.updateBars()
        #expect(meter.snapshot(reset: false).counts.barRenders == 1)
        #expect(!core.eventLoop.switchReads.barsOwed)
    }
}
