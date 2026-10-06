import Foundation
import Testing

@testable import KiwiDeskCore

/// A stop before a filed window arrives keeps its filing (#2008):
/// the snapshot carries every Space's not-yet-arrived windows, and
/// the next start files each back where it was. Measured on device:
/// a boot under the lock tracked 1 of 12 windows, and a stop then
/// put the other 11 on the active Space.
@Suite("Pending filings ride the snapshot (#2008)")
struct PendingFilingCarryTests {
    private let late = WindowID(2008)

    private func desk() -> StateCoordinator {
        var state = StateCoordinator()
        state.workspaces.ensureSpace(SpaceID(1))
        state.workspaces.ensureSpace(SpaceID(2))
        state.remember(late, in: SpaceID(2))
        return state
    }

    private func record(
        _ id: Int,
        in snapshot: StateSnapshot
    ) throws -> StateSnapshot.SpaceRecord {
        try #require(snapshot.spaces.first { $0.id == "\(id)" })
    }

    @Test("a stop and a start file a late window back in its Space")
    func roundTripRefilesTheLateWindow() throws {
        let snapshot = desk().snapshot()
        #expect(try record(2, in: snapshot).pending == [late.raw])
        #expect(try record(1, in: snapshot).pending.isEmpty)
        let decoded = try JSONDecoder().decode(
            StateSnapshot.self,
            from: JSONEncoder().encode(snapshot)
        )
        var next = StateCoordinator()
        next.workspaces.ensureSpace(SpaceID(1))
        next.workspaces.ensureSpace(SpaceID(2))
        next.adopt(decoded)
        #expect(next.rememberedSpace(of: late) == SpaceID(2))
    }

    @Test("a held Space carries its filings on the hold alone")
    func heldSpaceCarriesOnTheHold() throws {
        var state = desk()
        state.heldSpaces[SpaceID(2)] = HeldOrigin(
            name: SpaceID(4),
            screen: "DELL:2560x1440",
            icon: nil,
            arrangement: .standard("Dual")
        )
        let space = try record(2, in: state.snapshot())
        #expect(space.pending.isEmpty)
        #expect(space.held?.remembered == [late.raw])
    }

    @Test("a closed departure is not carried")
    func closedDepartureIsNotCarried() throws {
        var state = desk()
        state.closedDepartures.insert(late)
        #expect(try record(2, in: state.snapshot()).pending.isEmpty)
    }

    @Test("an older snapshot without the key decodes")
    func olderSnapshotDecodes() throws {
        let data = try JSONEncoder().encode(desk().snapshot())
        var json = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        var spaces = try #require(json["spaces"] as? [[String: Any]])
        for index in spaces.indices { spaces[index]["pending"] = nil }
        json["spaces"] = spaces
        let older = try JSONDecoder().decode(
            StateSnapshot.self,
            from: JSONSerialization.data(withJSONObject: json)
        )
        #expect(older.spaces.allSatisfy { $0.pending.isEmpty })
    }
}
