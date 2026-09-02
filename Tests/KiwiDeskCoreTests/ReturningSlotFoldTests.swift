import Foundation
import Testing

@testable import KiwiDeskCore

// The slot half of a Desktop return (#1207): a departed window
// carries the index it held, and the create fold re-inserts it by
// RANK against the members already back — so a row folded as
// destroys in one order and re-tracked in another comes back as
// it left, rather than in re-track order.

private let a = WindowID(1)
private let b = WindowID(2)
private let c = WindowID(3)
private let d = WindowID(4)
private let home = SpaceID(1)

private func makeWindow(_ id: WindowID) -> ManagedWindow {
    ManagedWindow(id: id, pid: pid_t(id.raw), appName: "App\(id.raw)")
}

/// A row [a, b, c, d], then the whole Desktop departs.
private func makeDepartedRow() -> StateCoordinator {
    var state = StateCoordinator()
    for id in [a, b, c, d] {
        state.apply(.windowCreated(makeWindow(id)))
        state.apply(.windowFocused(id))
    }
    #expect(state.workspaces[home]?.windows == [a, b, c, d])
    for id in [a, b, c, d] {
        state.apply(.windowDestroyed(id, wasMinimized: false))
    }
    return state
}

@Suite("A Desktop return keeps the row's order (#1207)")
struct ReturningSlotFoldTests {
    @Test("the departure records each window's slot")
    func departureRecordsSlots() {
        let state = makeDepartedRow()
        #expect(state.departedSlots == [a: 0, b: 1, c: 2, d: 3])
    }

    @Test("a scrambled re-track rebuilds the order it left")
    func scrambledReturnRebuildsTheOrder() {
        var state = makeDepartedRow()
        for id in [d, b, c, a] {
            state.apply(.windowCreated(makeWindow(id)))
        }
        #expect(state.workspaces[home]?.windows == [a, b, c, d])
    }

    /// The rank insertion, not the index: with only `d` back, `c`
    /// must land BEFORE it, which an insert-at-index would miss.
    @Test("a later slot already back is not overtaken")
    func rankNotIndex() {
        var state = makeDepartedRow()
        state.apply(.windowCreated(makeWindow(d)))
        state.apply(.windowCreated(makeWindow(c)))
        #expect(state.workspaces[home]?.windows == [c, d])
    }

    @Test("a member with no rank is passed over")
    func unrankedMemberIsPassedOver() {
        var state = makeDepartedRow()
        // A fresh spawn, no departure behind it: ordinary placement.
        state.apply(.windowCreated(makeWindow(WindowID(9))))
        state.apply(.windowCreated(makeWindow(b)))
        state.apply(.windowCreated(makeWindow(a)))
        // `a` ranks before `b`; the spawn keeps its place.
        #expect(
            state.workspaces[home]?.windows == [WindowID(9), a, b]
        )
    }

    /// A member that never departs is ranked by where it sits at
    /// each departure, so the returns fall in around it.
    @Test("a member that stayed keeps its place")
    func stayerKeepsItsPlace() {
        var state = StateCoordinator()
        let stayer = WindowID(9)
        for id in [stayer, a, b] {
            state.apply(.windowCreated(makeWindow(id)))
            state.apply(.windowFocused(id))
        }
        // A stale rank from some earlier departure.
        state.departedSlots[stayer] = 5
        for id in [a, b] {
            state.apply(.windowDestroyed(id, wasMinimized: false))
        }
        state.apply(.windowCreated(makeWindow(b)))
        state.apply(.windowCreated(makeWindow(a)))
        #expect(state.workspaces[home]?.windows == [stayer, a, b])
    }

    /// Ranks are as fresh as the space's last departure: a row
    /// re-ordered after a return, departing one window, comes back
    /// in the NEW order — never the rank of an earlier departure.
    @Test("a re-ordered row departing one window keeps the new order")
    func reorderedRowKeepsTheNewOrder() {
        var state = makeDepartedRow()
        for id in [a, b, c, d] {
            state.apply(.windowCreated(makeWindow(id)))
        }
        state.workspaces.withSpace(home) { $0.windows = [b, a, c, d] }
        state.apply(.windowDestroyed(a, wasMinimized: false))
        state.apply(.windowCreated(makeWindow(a)))
        #expect(state.workspaces[home]?.windows == [b, a, c, d])
    }

    @Test("a minimize records no slot")
    func minimizeRecordsNoSlot() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(a)))
        state.apply(.windowDestroyed(a, wasMinimized: true))
        #expect(state.departedSlots[a] == nil)
    }

    @Test("the reset forgets the slots with the spaces")
    func resetForgetsSlots() {
        var state = makeDepartedRow()
        state.forgetRememberedSpaces()
        #expect(state.departedSlots.isEmpty)
    }

    @Test("a re-key carries the slot to the fresh id")
    func rekeyCarriesTheSlot() {
        var state = makeDepartedRow()
        state.apply(.windowRekeyed(c, WindowID(9)))
        #expect(state.departedSlots[WindowID(9)] == 2)
        #expect(state.departedSlots[c] == nil)
    }
}
