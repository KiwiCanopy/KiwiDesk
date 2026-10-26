import Foundation
import Testing

@testable import KiwiDeskCore

/// The visibility settle pass re-stacks once per burst of steps
/// (#2659): an ask inside `dropSettleBurstGap` of the last one
/// waits the gap out, and a lone ask keeps its early timing.
@Suite("Border drop settle burst")
@MainActor
struct BorderDropSettleBurstTests {
    /// The waits the drop settle slot slept, read after it ran.
    private func recordWaits(_ core: KiwiCore) -> () -> [Duration] {
        @MainActor final class Box { var waits: [Duration] = [] }
        let box = Box()
        core.deferred.sleep = { wait in
            await MainActor.run { box.waits.append(wait) }
        }
        return { box.waits }
    }

    private func ask(_ core: KiwiCore) async {
        core.scheduleBorderDropReconcile()
        let pass = core.deferred.task(for: .borderDropSettle)
        #expect(pass != nil)
        await pass?.value
    }

    @Test("a lone ask settles early")
    func loneAskIsEarly() async {
        let core = makeTestCore()
        let waits = recordWaits(core)
        await ask(core)
        #expect(waits() == [.milliseconds(50)])
    }

    @Test("an ask inside the gap waits the burst out")
    func burstWaitsTheGap() async {
        let core = makeTestCore()
        let waits = recordWaits(core)
        await ask(core)
        await ask(core)
        #expect(
            waits() == [.milliseconds(50), KiwiCore.dropSettleBurstGap]
        )
        #expect(core.borders.lastSyncReassertedOrder == true)
    }

    @Test("an ask past the gap is lone again")
    func pastTheGapIsLone() async {
        let core = makeTestCore()
        let waits = recordWaits(core)
        let start = core.wallClock()
        await ask(core)
        core.wallClock = { start.addingTimeInterval(1.5) }
        await ask(core)
        #expect(waits() == [.milliseconds(50), .milliseconds(50)])
    }

    @Test("the gap fits a step pace and the bound outlasts it")
    func boundsAreOrdered() {
        #expect(KiwiCore.dropSettleBurstGap >= .milliseconds(500))
        #expect(KiwiCore.dropSettleMaxWait > KiwiCore.dropSettleBurstGap)
    }
}
