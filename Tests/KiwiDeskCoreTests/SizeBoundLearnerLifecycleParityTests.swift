import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The learner's per-window stores are hand-mirrored across four
/// lifecycle hooks — `forget`, `rekey`, `stashOnGone`, `revive` —
/// and the #1439 probe ledger made it five stores. Past
/// parity-tests.md's threshold, so this discovers the stores by
/// reflection: every `[WindowID: …]` map and `Set<WindowID>` on
/// the struct, whatever is added next, must forget and rekey.
///
/// Known limit, stated: the walk sees a store it can TYPE — a
/// map keyed by something other than `WindowID`, or a struct that
/// wraps the id, reads as unrelated and passes by being invisible
/// (`WindowRekeyParityTests`' blind spot, one struct over).
@Suite("Size-bound learner lifecycle parity (#1439)")
struct SizeBoundLearnerLifecycleParityTests {
    private let w = WindowID(7)
    private let new = WindowID(8)

    /// Every window-keyed store populated for `w` through the
    /// ladder: an ask, a candidate, a believed entry, a pending
    /// probe and a filed probe compliance.
    private func populated() -> SizeBoundLearner {
        var learner = SizeBoundLearner()
        let held = CGSize(width: 720, height: 800)
        learner.recordAsk(
            w,
            size: CGSize(width: 500, height: 800),
            settledFrom: held
        )
        learner.observe(w, currentSize: held, settledRead: true)
        learner.recordAsk(w, size: CGSize(width: 600, height: 800))
        learner.observe(w, currentSize: held, settledRead: true)
        learner.compliedProbes.insert(w)
        return learner
    }

    /// The stores by name, each read as the ids it holds.
    private func stores(
        of learner: SizeBoundLearner
    ) -> [(name: String, ids: Set<WindowID>)] {
        Mirror(reflecting: learner).children.compactMap { child in
            guard let name = child.label else { return nil }
            if let map = child.value as? [WindowID: Any] {
                return (name, Set(map.keys))
            }
            if let set = child.value as? Set<WindowID> {
                return (name, set)
            }
            return nil
        }
    }

    /// The tombstone is written BY the gone path and read by the
    /// revive, so it rightly survives a forget; it is keyed by
    /// the gone id and is not rekeyed either (#1049).
    private let exempt: Set<String> = ["tombstones"]

    @Test("Forget clears every window-keyed store")
    func forgetClearsEveryStore() {
        var learner = populated()
        let holding = stores(of: learner).filter { $0.ids.contains(w) }
        // Non-vacuity: the walk found the stores the ladder
        // filled, so a store it cannot type is a stated limit,
        // not an empty run.
        #expect(holding.count >= 5)
        learner.forget(w)
        for store in stores(of: learner)
        where !exempt.contains(store.name) {
            #expect(
                !store.ids.contains(w),
                "\(store.name) still holds the forgotten id"
            )
        }
    }

    @Test("Rekey moves every window-keyed store")
    func rekeyMovesEveryStore() {
        var learner = populated()
        let held = stores(of: learner)
            .filter { $0.ids.contains(w) }
            .map(\.name)
        learner.rekey(old: w, new: new)
        for store in stores(of: learner)
        where !exempt.contains(store.name) {
            #expect(
                !store.ids.contains(w),
                "\(store.name) still holds the old id"
            )
            if held.contains(store.name) {
                #expect(
                    store.ids.contains(new),
                    "\(store.name) lost its entry on rekey"
                )
            }
        }
    }
}
