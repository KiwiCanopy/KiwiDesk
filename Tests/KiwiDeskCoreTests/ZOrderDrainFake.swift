import Foundation
import Testing

@testable import KiwiDeskCore

/// A WindowServer whose apps perform their raises late, on a fake
/// clock that only advances when the drain sleeps. Deterministic,
/// and it never touches a real window.
///
/// Shared by `ZOrderDrainTests` (#684) and
/// `ZOrderTeardownDrainTests` (#688) rather than copied into
/// each. It is a ratified exception to tests.md's
/// per-file-helper convention, and **tests.md owns that list and
/// the grounds it was admitted on** — do not restate them here.
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

    /// The drain a live restore builds
    /// (`KiwiCore.performZOrderSequence`).
    func restoreDrain(above floor: [WindowID] = []) -> ZOrderDrain {
        drain(above: floor, policy: .restore)
    }

    /// The drain the quit-grid restack builds
    /// (`KiwiCore.teardownDrain`, #688).
    func teardownDrain(
        budget: TimeInterval? = nil
    ) -> ZOrderDrain {
        let policy = ZOrderDrain.Policy.teardown
        return drain(
            above: [],
            policy: budget.map(policy.limited(to:)) ?? policy
        )
    }

    /// One drain per production sequence, named after it, and
    /// each built from the SAME `ZOrderDrain.Policy` value its
    /// production call site passes — never a copy of that
    /// policy's fields. A hand-copied policy here would leave the
    /// suite proving what the drain does with a flag while
    /// production quietly handed it another, which is exactly
    /// what shipped once (guard-prover, 2026-08-03). A third
    /// sequence adds a third factory.
    private func drain(
        above floor: [WindowID],
        policy: ZOrderDrain.Policy
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
            policy: policy
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
