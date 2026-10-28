import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The pocket's in-place crossing (#2678): 4.1.0 writes the list
/// under `pockets`, and a 4.0.0 file's one slot under `pocket` is
/// read as a list of one, so an update relaunch strands no parked
/// window.
@Suite("Pocket snapshot crossing")
struct PocketSnapshotCrossingTests {
    private let one = WindowID(1)
    private let two = WindowID(2)

    private func snapshot() -> StateSnapshot {
        var snapshot = StateSnapshot(
            windows: [],
            spaces: [],
            activeSpace: nil
        )
        snapshot.pocket = [
            PocketSlot(window: one, phase: .pocketed),
            PocketSlot(window: two, phase: .out, focusedAt: 2),
        ]
        return snapshot
    }

    private func object(
        _ snapshot: StateSnapshot
    ) throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(snapshot)
            ) as? [String: Any]
        )
    }

    @Test("the list is written under pockets and read back in order")
    func listRoundTrips() throws {
        let written = try object(snapshot())
        #expect(written["pockets"] != nil)
        #expect(written["pocket"] == nil)
        let read = try JSONDecoder().decode(
            StateSnapshot.self,
            from: JSONEncoder().encode(snapshot())
        )
        #expect(read.pocket == snapshot().pocket)
    }

    @Test("a 4.0.0 file's one slot is read as a list of one")
    func singleSlotFolds() throws {
        var legacy = try object(snapshot())
        let slots = try #require(legacy["pockets"] as? [[String: Any]])
        var slot = try #require(slots.first)
        // 4.0.0 wrote no focus order.
        slot["focused_at"] = nil
        legacy["pockets"] = nil
        legacy["pocket"] = slot
        let read = try JSONDecoder().decode(
            StateSnapshot.self,
            from: JSONSerialization.data(withJSONObject: legacy)
        )
        #expect(read.pocket.map(\.window) == [one])
        #expect(read.pocket.first?.phase == .pocketed)
        #expect(read.pocket.first?.focusedAt == 0)
    }
}
