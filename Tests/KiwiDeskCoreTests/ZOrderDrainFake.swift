import Foundation
import Testing

@testable import KiwiDeskCore

/// The fake WindowServer the z-order drain suites run against,
/// shared by `ZOrderDrainTests` (#684) and
/// `ZOrderTeardownDrainTests` (#688) rather than copied into each.
///
/// A **sixth** ratified exception to tests.md's per-file-helper
/// convention, and the first admitted on the divergence ground
/// while carrying state — so it is worth saying which part of the
/// bar it clears and which it argues past.
///
/// The divergence harm is the strongest of any helper on that
/// list, because it has already happened here: a copy that models
/// every raise as reaching index 0 makes a landing condition no
/// real raise can satisfy look reachable, and that fake hid an
/// unachievable check under twelve green tests (#684). `pinned`
/// is what fixed it, and it is exactly the property #688's
/// suite depends on. Two copies means one of them can lose it
/// again, silently, in the suite that needs it most.
///
/// It is **not** stateless, which the five before it were. What
/// that requirement protects against is setup/teardown coupling
/// between suites, and this has none: every test constructs its
/// own instance, the state is that instance's fake clock and
/// window order, and nothing is shared or carried between tests.
/// It holds no assertions of its own. Statelessness was the proxy;
/// the isolation it stood for is intact.

/// A WindowServer whose apps perform their raises late, on a fake
/// clock that only advances when the drain sleeps. Deterministic,
/// and it never touches a real window.
final class FakeWindowServer: @unchecked Sendable {
    /// Front-to-back, the `CGWindowListCopyWindowInfo` order.
    private var order: [WindowID]
    /// Raises accepted but not yet performed, with their due time.
    private var inFlight: [(id: WindowID, due: TimeInterval)] = []

    /// Per-window delay between accepting a raise and performing
    /// it. `.infinity` is an app that never performs it at all.
    var latency: [WindowID: TimeInterval] = [:]
    var defaultLatency: TimeInterval = 0.01
    /// Every raise issued, in order.
    private(set) var raised: [WindowID] = []
    var clock: TimeInterval = 0
    /// How many raises this sequence stays current for, so a test
    /// can supersede it mid-drain.
    var currentUntilRaises = Int.max
    /// The frontmost app's key window, which a quiet raise cannot
    /// get above — measured on device, 0 of 7 windows over 600 ms.
    /// A raise lands directly UNDER it, not at the front. Modelled
    /// here because the fake's old "every raise reaches index 0"
    /// is what let a landing condition no real raise can satisfy
    /// sit under twelve green tests.
    var pinned: WindowID?

    init(order: [WindowID], pinned: WindowID? = nil) {
        self.order = order
        self.pinned = pinned
    }

    func drain(
        above floor: [WindowID] = [],
        budget: TimeInterval = ZOrderDrain.restoreBudget
    ) -> ZOrderDrain {
        ZOrderDrain(
            raise: { [self] id in
                raised.append(id)
                let delay = latency[id] ?? defaultLatency
                guard delay.isFinite else { return }
                inFlight.append((id, clock + delay))
            },
            stacking: { [self] in stacking() },
            now: { [self] in clock },
            sleep: { [self] seconds in clock += seconds },
            isCurrent: { [self] in
                raised.count < currentUntilRaises
            },
            floor: floor,
            budget: budget
        )
    }

    /// Performs everything now due — the newest raise ends up
    /// front, or directly under `pinned` where one is set — and
    /// answers the order.
    func stacking() -> [WindowID] {
        let due = inFlight.filter { $0.due <= clock }
            .sorted { $0.due < $1.due }
        inFlight.removeAll { $0.due <= clock }
        for entry in due where entry.id != pinned {
            order.removeAll { $0 == entry.id }
            let front =
                pinned.flatMap { order.firstIndex(of: $0) }
                .map { $0 + 1 } ?? 0
            order.insert(entry.id, at: front)
        }
        return order
    }
}
