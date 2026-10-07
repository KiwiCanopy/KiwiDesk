import ApplicationServices
import Testing

@testable import KiwiDeskCore

/// #837: an app-level registration stops at the first add that
/// stalls, so an unresponsive app costs one messaging timeout
/// rather than one per notification, and leaves the rest to
/// repair. The fake clock moves only inside a stalled add.
@Suite("Observer registration bound (#837)")
@MainActor
struct ObserverRegistrationBoundTests {
    private let names = ["a", "b", "c", "d"]

    /// Registers `names`; the adds in `stalls` take `cost` each,
    /// the ones in `refused` fail. Returns the failed set and the
    /// adds that ran.
    private func run(
        stalls: Set<String>,
        refused: Set<String> = [],
        cost: Duration = AXApplicationObserver.stalledAdd
    ) -> (failed: Set<String>, asked: [String], stalled: String?) {
        var clock = ContinuousClock.now
        var asked: [String] = []
        let result = AXApplicationObserver.register(
            names,
            now: { clock }
        ) { name in
            asked.append(name)
            if stalls.contains(name) { clock = clock.advanced(by: cost) }
            return refused.contains(name) ? .cannotComplete : .success
        }
        return (result.failed, asked, result.stalled)
    }

    @Test("a responsive app is asked for every notification")
    func responsiveAppAddsAll() {
        let result = run(stalls: [], refused: ["b"])
        #expect(result.asked == names)
        #expect(result.failed == ["b"])
        #expect(result.stalled == nil)
    }

    @Test("a stalled add ends the registration, the rest left failed")
    func stallStopsTheLoop() {
        let result = run(stalls: ["b"], refused: ["b"])
        #expect(result.asked == ["a", "b"])
        #expect(result.failed == ["b", "c", "d"])
        #expect(result.stalled == "b")
    }

    @Test("a stalled add that lands still counts as registered")
    func stalledSuccessIsRegistered() {
        let result = run(stalls: ["a"])
        #expect(result.asked == ["a"])
        #expect(result.failed == ["b", "c", "d"])
    }

    @Test("an add just under the bound does not stop the loop")
    func slowButUnderTheBoundContinues() {
        let result = run(
            stalls: ["a", "b", "c", "d"],
            cost: AXApplicationObserver.stalledAdd
                - .milliseconds(1)
        )
        #expect(result.asked == names)
        #expect(result.failed.isEmpty)
    }

    @Test("a stall backs repair off until the window passes")
    func stallBacksRepairOff() {
        let start = ContinuousClock.now
        let backoff = ObserverRegistrationLedger.repairBackoff
        var ledger = ObserverRegistrationLedger()
        #expect(!ledger.needsRepair(now: start))
        ledger.record((["a", "b", "c"], stalled: "a"), at: start)
        #expect(!ledger.needsRepair(now: start))
        #expect(
            !ledger.needsRepair(
                now: start.advanced(by: backoff - .seconds(1))
            )
        )
        #expect(ledger.needsRepair(now: start.advanced(by: backoff)))
        // A session's return forgets the stall at once.
        ledger.forgetStall()
        #expect(ledger.needsRepair(now: start))
        // A refusal with no stall is owed at once.
        ledger.record((["b"], stalled: nil), at: start)
        #expect(ledger.needsRepair(now: start))
        ledger.record(([], stalled: nil), at: start)
        #expect(!ledger.needsRepair(now: start))
    }

    @Test("repair asks only the failed adds, the stalled one last")
    func repairAsksTheStalledAddLast() {
        let declared = ["a", "b", "c", "d"]
        var ledger = ObserverRegistrationLedger()
        ledger.record((["a", "c", "d"], stalled: "a"), at: .now)
        #expect(ledger.repairOrder(of: declared) == ["c", "d", "a"])
        ledger.record((["a", "c"], stalled: nil), at: .now)
        #expect(ledger.repairOrder(of: declared) == ["a", "c"])
    }
}
