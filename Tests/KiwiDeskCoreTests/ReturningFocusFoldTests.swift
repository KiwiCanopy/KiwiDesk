import Foundation
import Testing

@testable import KiwiDeskCore

// The pure half of the Desktop return's focus memory (#1207):
// what the `.windowCreated` fold does with the owed window
// mirrored in as `returningFocus`. The Desktop departure folds
// every window of the left Desktop as a destroy, and the walk
// down the survivors leaves `Space.focused` nil — or on a carried
// sticky window (#1145), the one member that never departs. On
// the return the first re-tracked window used to take that
// vacancy (#636's nil arm), which is the first-in-row jump.

/// TextEdit: the window the user had focused when they left.
private let owed = WindowID(1)
/// Claude: first in the row, and the first to re-list.
private let first = WindowID(2)
/// A carried sticky window (#1145): never departed.
private let carried = WindowID(3)
private let home = SpaceID(1)

private func makeWindow(
    _ id: WindowID,
    isTransientOverlay: Bool = false
) -> ManagedWindow {
    ManagedWindow(
        id: id,
        pid: pid_t(id.raw),
        appName: "App\(id.raw)",
        isTransientOverlay: isTransientOverlay
    )
}

/// The Desktop the user is about to leave: `first` and `owed` in
/// the home space, `owed` focused (the spawn grant gives the last
/// create the focus).
private func makeDesktop(
    carrying: Bool = false,
    owedIsOverlay: Bool = false
) -> StateCoordinator {
    var state = StateCoordinator()
    state.apply(.windowCreated(makeWindow(first)))
    if carrying {
        state.apply(.windowCreated(makeWindow(carried)))
    }
    state.apply(
        .windowCreated(
            makeWindow(owed, isTransientOverlay: owedIsOverlay)
        )
    )
    state.apply(.windowFocused(owed))
    return state
}

/// The departure burst: every window of the left Desktop folds
/// as a destroy, in arbitrary per-pid order.
private func depart(_ state: inout StateCoordinator) {
    state.apply(.windowDestroyed(owed, wasMinimized: false))
    state.apply(.windowDestroyed(first, wasMinimized: false))
}

@Suite("A Desktop return's owed focus in the create fold (#1207)")
struct ReturningFocusFoldTests {
    @Test("the owed returning window takes the focus beside a non-nil one")
    func owedReturnTakesTheFocusBesideACarriedSticky() {
        var state = makeDesktop(carrying: true)
        depart(&state)
        // The walk landed on the one member that stayed.
        #expect(state.workspaces[home]?.focused == carried)
        state.returningFocus = owed
        let effects = state.apply(.windowCreated(makeWindow(owed)))
        #expect(state.workspaces[home]?.focused == owed)
        #expect(effects.paidReturningFocus)
        // Consumed by the fold, like `arrivalDisplay`.
        #expect(state.returningFocus == nil)
    }

    @Test("another returning window leaves the vacancy to the owed one")
    func vacancyIsHeldWhileTheOwedWindowIsDeparted() {
        var state = makeDesktop()
        depart(&state)
        #expect(state.workspaces[home]?.focused == nil)
        // The first re-track is not the owed window: the nil arm
        // is refused for this space.
        state.returningFocus = owed
        let refused = state.apply(
            .windowCreated(makeWindow(first))
        )
        #expect(state.workspaces[home]?.focused == nil)
        #expect(!refused.paidReturningFocus)
        // …and the owed window's own arrival is the payment.
        state.returningFocus = owed
        let paid = state.apply(.windowCreated(makeWindow(owed)))
        #expect(state.workspaces[home]?.focused == owed)
        #expect(paid.paidReturningFocus)
    }

    @Test("without a debt the first arrival takes the vacancy (#636)")
    func noDebtKeepsTheVacancyRule() {
        var state = makeDesktop()
        depart(&state)
        state.returningFocus = nil
        state.apply(.windowCreated(makeWindow(first)))
        #expect(state.workspaces[home]?.focused == first)
    }

    /// The `windows[owed] == nil` clause: a debt naming a window
    /// that is already back — re-homed to another space by #1010,
    /// say — holds no vacancy anywhere.
    @Test("an owed window already present blocks nothing")
    func presentOwedWindowBlocksNothing() {
        var state = makeDesktop()
        depart(&state)
        state.apply(.windowCreated(makeWindow(owed)))
        // Moved on: the home space is focusless again while the
        // owed window lives elsewhere with its departed memory.
        state.workspaces.add(owed, to: SpaceID(2))
        #expect(state.workspaces[home]?.focused == nil)
        #expect(state.rememberedSpaces[owed] == .departed(home))
        state.returningFocus = owed
        state.apply(.windowCreated(makeWindow(first)))
        #expect(state.workspaces[home]?.focused == first)
    }

    /// The `.departed(target)` clause: a debt whose window
    /// departed some OTHER space holds no vacancy here.
    @Test("a window departed from another space holds no vacancy here")
    func departureElsewhereHoldsNothing() {
        var state = makeDesktop()
        state.workspaces.add(owed, to: SpaceID(2))
        depart(&state)
        #expect(state.rememberedSpaces[owed] == .departed(SpaceID(2)))
        state.returningFocus = owed
        state.apply(.windowCreated(makeWindow(first)))
        #expect(state.workspaces[home]?.focused == first)
    }

    /// The provenance half of that clause: a `.restored` memory
    /// is KiwiDesk's own filing from a snapshot, never an observed
    /// departure, so it holds no vacancy either — only a window
    /// the destroy fold saw leave THIS space does.
    @Test("a restored memory for the owed window holds no vacancy")
    func restoredMemoryHoldsNothing() {
        var state = makeDesktop()
        depart(&state)
        state.rememberedSpaces[owed] = .restored(home)
        state.returningFocus = owed
        state.apply(.windowCreated(makeWindow(first)))
        #expect(state.workspaces[home]?.focused == first)
    }

    @Test("a fresh spawn carrying the owed id is not a payment")
    func freshSpawnIsNotAPayment() {
        var state = StateCoordinator()
        state.apply(.windowCreated(makeWindow(first)))
        state.returningFocus = owed
        let effects = state.apply(.windowCreated(makeWindow(owed)))
        // The ordinary spawn grant, reported as no payment.
        #expect(state.workspaces[home]?.focused == owed)
        #expect(!effects.paidReturningFocus)
    }

    @Test("a return into a space that is not active is not paid")
    func returnIntoInactiveSpaceIsNotPaid() {
        var state = makeDesktop()
        depart(&state)
        state.workspaces.ensureSpace(SpaceID(2))
        state.workspaces.activate(SpaceID(2))
        state.returningFocus = owed
        let effects = state.apply(.windowCreated(makeWindow(owed)))
        #expect(state.workspaces.space(of: owed) == home)
        #expect(!effects.paidReturningFocus)
    }

    @Test("a transient overlay is granted nothing, owed or not")
    func overlayIsGrantedNothing() {
        var state = makeDesktop(carrying: true, owedIsOverlay: true)
        depart(&state)
        state.returningFocus = owed
        let effects = state.apply(
            .windowCreated(
                makeWindow(owed, isTransientOverlay: true)
            )
        )
        #expect(state.workspaces[home]?.focused == carried)
        #expect(!effects.paidReturningFocus)
    }
}
