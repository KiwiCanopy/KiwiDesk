import Foundation
import Testing

@testable import KiwiDeskCore

/// The visibility settle pass re-stacks once per burst of steps
/// (#2659): an ask within the gap of the pass last running waits
/// the gap out, asks before a pass runs are one ask, and a burst
/// runs its pass at least every `maxWait`.
@Suite("Border drop settle burst")
@MainActor
struct BorderDropSettleBurstTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 1_000)
    private let early: TimeInterval = 0.05

    @Test("a lone ask settles early")
    func loneAskIsEarly() {
        var burst = DropSettleBurst()
        #expect(burst.wait(asking: t0, early: early) == early)
    }

    @Test("asks before the pass runs are one lone ask")
    func asksBeforeARunAreOne() {
        var burst = DropSettleBurst()
        #expect(burst.wait(asking: t0, early: early) == early)
        #expect(burst.wait(asking: t0, early: early) == early)
    }

    @Test("an ask inside the gap after a run waits the burst out")
    func askAfterARunWaitsTheGap() {
        var burst = DropSettleBurst()
        burst.ran(at: t0)
        let ask = t0.addingTimeInterval(0.25)
        #expect(burst.wait(asking: ask, early: early) == DropSettleBurst.gap)
        let next = ask.addingTimeInterval(1.2)
        #expect(burst.wait(asking: next, early: early) == DropSettleBurst.gap)
    }

    /// A drop's ask un-hides its swap target, so a pass run for an
    /// earlier retile of the same gesture never delays it.
    @Test("a lone ask settles early right after a run")
    func loneAskAfterARunIsEarly() {
        var burst = DropSettleBurst()
        burst.ran(at: t0)
        let ask = t0.addingTimeInterval(0.25)
        #expect(burst.wait(asking: ask, early: early, lone: true) == early)
        #expect(burst.wait(asking: ask, early: early) == DropSettleBurst.gap)
    }

    @Test("an ask past the gap is lone again")
    func pastTheGapIsLone() {
        var burst = DropSettleBurst()
        burst.ran(at: t0)
        let ask = t0.addingTimeInterval(DropSettleBurst.gap + 0.5)
        #expect(burst.wait(asking: ask, early: early) == early)
    }

    @Test("a burst runs its pass by maxWait")
    func burstIsBounded() {
        var burst = DropSettleBurst()
        burst.ran(at: t0)
        let start = t0.addingTimeInterval(0.5)
        _ = burst.wait(asking: start, early: early)
        let late = start.addingTimeInterval(DropSettleBurst.maxWait - 0.4)
        let wait = burst.wait(asking: late, early: early)
        #expect(abs(wait - 0.4) < 0.001)
        let over = start.addingTimeInterval(DropSettleBurst.maxWait + 1)
        #expect(burst.wait(asking: over, early: early) == 0)
        burst.ran(at: over)
        #expect(burst.pendingSince == nil)
        let next = over.addingTimeInterval(DropSettleBurst.gap + 1)
        #expect(burst.wait(asking: next, early: early) == early)
    }

    /// Asks closer than the early wait never let a pass run; the
    /// bound still does.
    @Test("asks faster than the early wait are bounded too")
    func fastLoneAsksAreBounded() {
        var burst = DropSettleBurst()
        var ask = t0
        var waits: [TimeInterval] = []
        let end = t0.addingTimeInterval(DropSettleBurst.maxWait + 0.1)
        while ask <= end {
            waits.append(burst.wait(asking: ask, early: early))
            ask = ask.addingTimeInterval(0.04)
        }
        #expect(waits.first == early)
        #expect(waits.last == 0)
    }

    /// The core asks through the type and stamps the run in the
    /// pass's own body, so a drop's two asks keep the early wait.
    @Test("the core's pass stamps its run and a drop stays early")
    func coreStampsTheRun() async {
        @MainActor final class Box { var waits: [Duration] = [] }
        let box = Box()
        let core = makeTestCore()
        core.deferred.sleep = { wait in
            await MainActor.run { box.waits.append(wait) }
        }
        core.scheduleBorderDropReconcile()
        core.scheduleBorderDropReconcile()
        await core.deferred.task(for: .borderDropSettle)?.value
        #expect(box.waits.last == .milliseconds(50))
        #expect(core.borders.dropSettleBurst.ranAt == core.wallClock())
        #expect(core.borders.lastSyncReassertedOrder == true)
        core.scheduleBorderDropReconcile()
        let pass = core.deferred.task(for: .borderDropSettle)
        await pass?.value
        #expect(box.waits.last == .seconds(1))
    }
}
