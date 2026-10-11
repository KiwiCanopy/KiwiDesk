import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A stop before a filed window arrives keeps its filing (#2008):
/// every capture carries each Space's not-yet-arrived windows and
/// the frames owed at their arrival, and the next start files each
/// back where it was.
@Suite("Pending filings ride the snapshot (#2008)")
@MainActor
struct PendingFilingCarryTests {
    private let owed = CGRect(x: 40, y: 50, width: 600, height: 400)
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

    @Test("a departure is carried; an unjudged filing is not")
    func departureCarriedUnjudgedNot() throws {
        var state = desk()
        let away = WindowID(2009)
        state.rememberedSpaces[away] = .departed(SpaceID(2))
        state.unjudgedFilings.insert(late)
        state.restoredFrames[late] = .init(frame: owed)
        let snapshot = state.snapshot()
        #expect(try record(2, in: snapshot).pending == [away.raw])
        #expect(!snapshot.windows.contains { $0.windowID == late })
    }

    @Test("both captures carry the filing and its owed frame")
    func bothCapturesCarry() throws {
        for inPlace in [false, true] {
            let core = makeTestCore()
            core.state.workspaces.ensureSpace(SpaceID(2))
            core.state.remember(late, in: SpaceID(2))
            core.state.restoredFrames[late] = .init(frame: owed)
            let snapshot = core.sessionSnapshot(inPlace: inPlace)
            #expect(try record(2, in: snapshot).pending == [late.raw])
            #expect(
                snapshot.windows.first { $0.windowID == late }?.frame
                    == owed
            )
        }
    }

    @Test("a wake replay leaves the filings to the live process")
    func wakeReplayDropsPending() throws {
        let snapshot = desk().snapshot()
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1440, height: 900)
        }
        core.state.workspaces.ensureSpace(SpaceID(2))
        core.restoreAndSettleAfterWake(snapshot)
        #expect(core.state.rememberedSpace(of: late) == nil)
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
