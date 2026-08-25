import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The classes the #1010 screen-wins rule deliberately does NOT
/// re-home, each for a different reason — split from
/// `ArrivalScreenHomeTests` at the 350-line ceiling (§2.1), with
/// which it shares only its fixture (per-file private helpers,
/// tests.md). That suite holds the rule and the arms that fall
/// out of the predicate's own geometry; this one holds the arms
/// that are RULINGS, and would otherwise read as oversights:
/// a float, a sticky window of either scope, and a remembered
/// space KiwiDesk filed itself rather than watched being left.
///
/// Each stand-down's argument lives on `screenHome`, once; the
/// comment above each test says only which one it is.
@Suite("Cross-screen arrival stand-downs (#1010)")
struct ArrivalScreenStandDownTests {
    private let displayA = DisplayID(1)
    private let displayB = DisplayID(2)
    private let mover = WindowID(11)

    /// Spaces 1–2 on the main screen, 5–6 on the second one,
    /// with the main screen focused and showing space 1 — the
    /// reported two-screen layout. The second screen sits at a
    /// negative y like the verifying machine's, which no pure
    /// state read touches: it is the flip that would have made a
    /// frame comparison silently wrong here.
    ///
    /// The second screen deliberately SHOWS its second-assigned
    /// space (6, not 5). "The space that display shows" and "the
    /// first space assigned to it" are different questions, and
    /// on a screen with one space they cannot be told apart — a
    /// re-home reading `spaces(on:).first` passed the whole
    /// suite before this (guard-prover, 2026-08-25).
    private func twoScreens() -> StateCoordinator {
        var state = StateCoordinator(defaultSpace: SpaceID("1"))
        state.workspaces.upsertDisplay(
            Display(
                id: displayA,
                name: "Main",
                frame: CGRect(
                    x: 0,
                    y: 0,
                    width: 1728,
                    height: 1117
                )
            )
        )
        state.workspaces.upsertDisplay(
            Display(
                id: displayB,
                name: "Second",
                frame: CGRect(
                    x: 1728,
                    y: -164,
                    width: 1920,
                    height: 1080
                )
            )
        )
        state.workspaces.ensureSpace(SpaceID("2"))
        state.workspaces.ensureSpace(SpaceID("5"))
        state.workspaces.ensureSpace(SpaceID("6"))
        state.workspaces.assign(SpaceID("1"), to: displayA)
        state.workspaces.assign(SpaceID("2"), to: displayA)
        state.workspaces.assign(SpaceID("5"), to: displayB)
        state.workspaces.assign(SpaceID("6"), to: displayB)
        // Show 6 on the second screen, then hand focus back to
        // the main one — which parks 6 as B's shown space.
        state.workspaces.activate(SpaceID("6"))
        state.workspaces.activate(SpaceID("1"))
        return state
    }

    private func window(
        _ id: WindowID = WindowID(11),
        bundleID: String? = nil,
        isFloating: Bool = false,
        sticky: StickyScope = .none
    ) -> ManagedWindow {
        ManagedWindow(
            id: id,
            pid: 100,
            appName: "TextEdit",
            appBundleID: bundleID,
            title: "Doc",
            isFloating: isFloating,
            stickyScope: sticky
        )
    }

    /// Lands `mover` in `space`, then departs it the way a
    /// Desktop move does — a non-minimized destroy, which is
    /// what writes the remembered space.
    private func depart(
        _ state: inout StateCoordinator,
        from space: SpaceID,
        _ departing: ManagedWindow? = nil
    ) {
        let departing = departing ?? window()
        state.workspaces.activate(space)
        state.apply(.windowCreated(departing))
        #expect(state.workspaces.space(of: mover) == space)
        state.apply(
            .windowDestroyed(mover, wasMinimized: false)
        )
    }

    @Test("A floating arrival keeps its remembered space")
    func aFloatingArrivalIsLeftAlone() {
        var state = twoScreens()
        depart(&state, from: SpaceID("1"), window(isFloating: true))
        // The defect is the LAYOUT carrying a window home, and a
        // float is never laid out — so a float never bounced,
        // and its cross-display anchoring is #444's and #412's
        // to rule, not this arrival's.
        state.arrivalDisplay = displayB
        let effects = state.apply(
            .windowCreated(window(isFloating: true))
        )
        #expect(state.workspaces.space(of: mover) == SpaceID("1"))
        #expect(effects.rehomedToScreenSpace == nil)
    }

    @Test("A global sticky arrival keeps its remembered space")
    func aGlobalStickyArrivalIsLeftAlone() {
        var state = twoScreens()
        depart(&state, from: SpaceID("1"), window(sticky: .global))
        // Re-homing a sticky window is the one membership move
        // `stickyMoveRefused` (#445) gates at every command
        // choke point, and a pure fold can neither call that
        // gate nor flash its refusal. A global sticky renders
        // on the FOCUSED display, so its frame sits on another
        // screen than its home space routinely — exactly the
        // shape that would be re-homed by accident.
        state.arrivalDisplay = displayB
        let effects = state.apply(
            .windowCreated(window(sticky: .global))
        )
        #expect(state.workspaces.space(of: mover) == SpaceID("1"))
        #expect(effects.rehomedToScreenSpace == nil)
    }

    @Test("A display sticky arrival keeps its remembered space")
    func aDisplayStickyArrivalIsLeftAlone() {
        var state = twoScreens()
        depart(&state, from: SpaceID("1"), window(sticky: .display))
        // The scope does not change the answer: #445 derives a
        // display sticky's home DISPLAY from its home space, so
        // re-homing one silently moves the monitor it lives on
        // — the move its own gate refuses to make quietly.
        state.arrivalDisplay = displayB
        let effects = state.apply(
            .windowCreated(window(sticky: .display))
        )
        #expect(state.workspaces.space(of: mover) == SpaceID("1"))
        #expect(effects.rehomedToScreenSpace == nil)
    }

    @Test("A restored memory is not a departure, so it stands")
    func aRestoredMemoryIsLeftAlone() {
        var state = twoScreens()
        // `StateSnapshot.adopt`'s filing for a window KiwiDesk
        // is not tracking yet — the layout it must put back,
        // never an observed departure. After an undock macOS
        // piles windows onto the built-in screen; following
        // THAT frame would discard the snapshot's whole point.
        state.remember(mover, in: SpaceID("5"))
        state.arrivalDisplay = displayA
        let effects = state.apply(.windowCreated(window()))
        #expect(state.workspaces.space(of: mover) == SpaceID("5"))
        #expect(effects.rehomedToScreenSpace == nil)
    }

    @Test("A departure after a restore re-arms the rule")
    func aDepartureAfterARestoreIsEligible() {
        var state = twoScreens()
        // The tag is the LAST writer's: a window filed by a
        // restore and then genuinely sent away is a departure
        // like any other, or the stand-down above would be
        // permanent for the rest of the session.
        state.remember(mover, in: SpaceID("1"))
        depart(&state, from: SpaceID("1"))
        state.arrivalDisplay = displayB
        let effects = state.apply(.windowCreated(window()))
        #expect(state.workspaces.space(of: mover) == SpaceID("6"))
        #expect(effects.rehomedToScreenSpace == SpaceID("6"))
    }

    @Test("The arrival's screen is consumed, never carried on")
    func theArrivalDisplayIsConsumed() {
        var state = twoScreens()
        depart(&state, from: SpaceID("1"))
        state.arrivalDisplay = displayB
        state.apply(.windowCreated(window()))
        #expect(state.arrivalDisplay == nil)
        // So the NEXT arrival, for which no producer resolved a
        // screen, cannot inherit this one's: window 33 left
        // space 2 on the main screen and comes back to it.
        state.workspaces.activate(SpaceID("2"))
        state.apply(.windowCreated(window(WindowID(33))))
        state.apply(
            .windowDestroyed(WindowID(33), wasMinimized: false)
        )
        state.workspaces.activate(SpaceID("1"))
        let effects = state.apply(
            .windowCreated(window(WindowID(33)))
        )
        #expect(
            state.workspaces.space(of: WindowID(33))
                == SpaceID("2")
        )
        #expect(effects.rehomedToScreenSpace == nil)
    }

}
