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
        let stalled = ContinuousClock.now
        let due = { (after: Duration) in
            AXApplicationObserver.repairDue(
                failed: true,
                stalledAt: stalled,
                now: stalled.advanced(by: after)
            )
        }
        #expect(!due(.zero))
        #expect(!due(AXApplicationObserver.repairBackoff - .seconds(1)))
        #expect(due(AXApplicationObserver.repairBackoff))
        #expect(
            AXApplicationObserver.repairDue(
                failed: true,
                stalledAt: nil,
                now: stalled
            )
        )
        #expect(
            !AXApplicationObserver.repairDue(
                failed: false,
                stalledAt: nil,
                now: stalled
            )
        )
    }

    @Test("repair asks the add that stalled last")
    func repairAsksTheStalledAddLast() {
        let failed: Set<String> = [
            kAXWindowCreatedNotification,
            kAXFocusedWindowChangedNotification,
            kAXWindowMiniaturizedNotification,
        ]
        #expect(
            AXApplicationObserver.repairOrder(
                failed: failed,
                stalled: kAXWindowCreatedNotification
            ) == [
                kAXFocusedWindowChangedNotification,
                kAXWindowMiniaturizedNotification,
                kAXWindowCreatedNotification,
            ]
        )
        #expect(
            AXApplicationObserver.repairOrder(failed: failed, stalled: nil)
                .first == kAXWindowCreatedNotification
        )
    }
}
