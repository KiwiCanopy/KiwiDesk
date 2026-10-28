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
            PocketSlot(window: two, phase: .out),
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
        let slots = try #require(legacy["pockets"] as? [Any])
        legacy["pockets"] = nil
        legacy["pocket"] = slots.first
        let read = try decode(legacy)
        #expect(read.pocket.map(\.window) == [one])
        #expect(read.pocket.first?.phase == .pocketed)
    }

    @Test("an unreadable slot costs only itself")
    func badSlotCostsItself() throws {
        var written = try object(snapshot())
        var slots = try #require(written["pockets"] as? [[String: Any]])
        slots[0]["phase"] = "lost"
        written["pockets"] = slots
        #expect(try decode(written).pocket.map(\.window) == [two])
    }

    @Test("a list outranks a single slot beside it")
    func listOutranksSingle() throws {
        var written = try object(snapshot())
        let slots = try #require(written["pockets"] as? [Any])
        written["pocket"] = slots.last
        #expect(try decode(written).pocket.map(\.window) == [one, two])
    }

    private func decode(_ object: [String: Any]) throws -> StateSnapshot {
        try JSONDecoder().decode(
            StateSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
    }
}
