import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The shared #1010 predicate asked the way the **Desktop verb**
/// asks it — about a window it is ABOUT to send to another
/// screen's Desktop, from the space it is a member of now.
///
/// `ArrivalScreenHomeTests` asks the same predicate through the
/// create fold, for a window coming back. Both are needed
/// because only one fires per move: a hidden target Desktop
/// takes the window out of KiwiDesk's view and the answer is
/// owed on its return; a target Desktop the screen is already
/// SHOWING produces no departure at all, and the command is the
/// only place the answer can be given. Device-measured
/// 2026-08-25 — with the arrival half alone, that second route
/// still snapped the window back inside 0.6 s.
///
/// The command's own wiring — that `moveToDesktop` asks this at
/// all, and resolves the target screen — is
/// `DesktopMoveRehomeWiringTests`', because the display comes
/// from a live UUID lookup no headless run can answer.
@Suite("Cross-screen re-home predicate (#1010)")
struct ScreenHomePredicateTests {
    private let displayA = DisplayID(1)
    private let displayB = DisplayID(2)
    private let mover = WindowID(11)

    /// Space 1 on the main screen, 5–6 on the second, which
    /// shows 6 — its SECOND-assigned space, so "the space that
    /// display shows" cannot be confused with "the first space
    /// assigned to it".
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
                    width: 2560,
                    height: 1440
                )
            )
        )
        state.workspaces.ensureSpace(SpaceID("5"))
        state.workspaces.ensureSpace(SpaceID("6"))
        state.workspaces.assign(SpaceID("1"), to: displayA)
        state.workspaces.assign(SpaceID("5"), to: displayB)
        state.workspaces.assign(SpaceID("6"), to: displayB)
        state.workspaces.activate(SpaceID("6"))
        state.workspaces.activate(SpaceID("1"))
        return state
    }

    private func window(
        isFloating: Bool = false,
        sticky: StickyScope = .none
    ) -> ManagedWindow {
        ManagedWindow(
            id: mover,
            pid: 100,
            appName: "TextEdit",
            title: "Doc",
            isFloating: isFloating,
            stickyScope: sticky
        )
    }

    /// A tracked window in space 1 on the main screen.
    private func placed(
        _ window: ManagedWindow
    ) -> StateCoordinator {
        var state = twoScreens()
        state.apply(.windowCreated(window))
        #expect(state.workspaces.space(of: mover) == SpaceID("1"))
        return state
    }

    @Test("A window sent to another screen takes its space")
    func crossingScreensTakesTheShownSpace() {
        let state = placed(window())
        #expect(
            state.screenHome(
                of: window(),
                leaving: SpaceID("1"),
                landingOn: displayB
            ) == SpaceID("6")
        )
    }

    @Test("A Desktop on the window's own screen moves nothing")
    func sameScreenMovesNothing() {
        let state = placed(window())
        #expect(
            state.screenHome(
                of: window(),
                leaving: SpaceID("1"),
                landingOn: displayA
            ) == nil
        )
    }

    @Test("A window already in that screen's space stays put")
    func alreadyThereMovesNothing() {
        var state = twoScreens()
        state.workspaces.activate(SpaceID("6"))
        state.apply(.windowCreated(window()))
        #expect(state.workspaces.space(of: mover) == SpaceID("6"))
        #expect(
            state.screenHome(
                of: window(),
                leaving: SpaceID("6"),
                landingOn: displayB
            ) == nil
        )
    }

    @Test("An unresolvable landing screen moves nothing")
    func noLandingDisplayMovesNothing() {
        let state = placed(window())
        #expect(
            state.screenHome(
                of: window(),
                leaving: SpaceID("1"),
                landingOn: nil
            ) == nil
        )
    }

    @Test("A window in no space moves nothing")
    func noHomeMovesNothing() {
        let state = twoScreens()
        #expect(
            state.screenHome(
                of: window(),
                leaving: nil,
                landingOn: displayB
            ) == nil
        )
    }

    @Test("A floating window is never re-homed")
    func floatingMovesNothing() {
        let state = placed(window(isFloating: true))
        #expect(
            state.screenHome(
                of: window(isFloating: true),
                leaving: SpaceID("1"),
                landingOn: displayB
            ) == nil
        )
    }

    @Test("A sticky window is never re-homed, either scope")
    func stickyMovesNothing() {
        for scope in [StickyScope.global, .display] {
            let state = placed(window(sticky: scope))
            #expect(
                state.screenHome(
                    of: window(sticky: scope),
                    leaving: SpaceID("1"),
                    landingOn: displayB
                ) == nil
            )
        }
    }

    @Test("A screen with no space of its own offers no home")
    func aScreenWithNoSpaceOffersNothing() {
        var state = placed(window())
        state.workspaces.removeDisplay(displayB)
        state.workspaces.upsertDisplay(
            Display(
                id: displayB,
                name: "Second",
                frame: CGRect(
                    x: 1728,
                    y: -164,
                    width: 2560,
                    height: 1440
                )
            )
        )
        #expect(
            state.screenHome(
                of: window(),
                leaving: SpaceID("1"),
                landingOn: displayB
            ) == nil
        )
    }
}
