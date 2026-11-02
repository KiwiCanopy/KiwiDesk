import Foundation
import Testing

@testable import KiwiDeskCore

/// A window on another Desktop keeps its slot across a restart
/// (#2907): the capture writes each Space's not-yet-arrived
/// windows in slot order, the start gives each that slot back, and
/// a carried window resumed as a departure returns to it — on the
/// device the row came back in id order, App Store moving from
/// first to last (2026-11-02).
@Suite("Pending filings carry their slots (#2907)")
@MainActor
struct PendingSlotCarryTests {
    private let space = SpaceID(2)
    /// Slot order deliberately unlike id order.
    private let row = [WindowID(30), WindowID(10), WindowID(20)]
    private let unranked = WindowID(5)

    private func departedDesk() -> StateCoordinator {
        var state = StateCoordinator()
        state.workspaces.ensureSpace(SpaceID(1))
        state.workspaces.ensureSpace(space)
        for (rank, id) in row.enumerated() {
            state.rememberedSpaces[id] = .departed(space)
            state.departedSlots[id] = .init(rank: rank)
        }
        state.remember(unranked, in: space)
        return state
    }

    private func restarted() throws -> StateCoordinator {
        let snapshot = try JSONDecoder().decode(
            StateSnapshot.self,
            from: JSONEncoder().encode(departedDesk().snapshot())
        )
        var next = StateCoordinator()
        next.workspaces.ensureSpace(SpaceID(1))
        next.workspaces.ensureSpace(space)
        next.adopt(snapshot)
        return next
    }

    @Test("the capture lists the pending windows in slot order")
    func captureFollowsTheSlots() throws {
        let record = try #require(
            departedDesk().snapshot().spaces.first { $0.id == "2" }
        )
        #expect(record.pending == (row + [unranked]).map(\.raw))
    }

    @Test("the start gives each carried window its slot back")
    func startRestoresTheSlots() throws {
        let next = try restarted()
        for (rank, id) in (row + [unranked]).enumerated() {
            #expect(next.rememberedSpaces[id] == .restored(space))
            #expect(next.departedSlots[id]?.rank == rank)
        }
    }

    @Test("a resumed departure returns to its slot, whatever the order")
    func resumedReturnTakesItsSlot() throws {
        var next = try restarted()
        for id in row {
            let resumed = next.resumeCarriedDeparture(id)
            #expect(resumed)
        }
        #expect(next.rememberedSpaces[row[0]] == .departed(space))
        next.workspaces.activate(space)
        // macOS re-lists the windows in its own order.
        for id in row.sorted(by: { $0.raw < $1.raw }) {
            next.apply(
                .windowCreated(
                    ManagedWindow(id: id, pid: 1, appName: "App")
                )
            )
        }
        #expect(next.workspaces[space]?.windows == row)
    }

    @Test("only a carried filing resumes as a departure")
    func onlyCarriedFilingsResume() {
        var state = StateCoordinator()
        state.workspaces.ensureSpace(space)
        state.remember(unranked, in: space)
        let plain = state.resumeCarriedDeparture(unranked)
        let unknown = state.resumeCarriedDeparture(WindowID(99))
        #expect(!plain && !unknown)
        #expect(state.rememberedSpaces[unranked] == .restored(space))
    }

    @Test("a filing judged gone takes its slot with it")
    func goneFilingDropsItsSlot() throws {
        var next = try restarted()
        next.forgetRestoredFiling(of: row[0])
        #expect(next.rememberedSpaces[row[0]] == nil)
        #expect(next.departedSlots[row[0]] == nil)
    }
}
