import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// SCREEN WINS (#1010): a window that comes back on a display
/// OTHER than the one its remembered space lays out on joins the
/// space THAT display shows. `move_to_desktop 3` onto a second
/// screen's Desktop used to undo itself a second after the
/// Desktop was revealed — the arrival rejoined its remembered
/// space, the retile carried it to that space's screen, and
/// macOS re-assigned its Desktop to match the frame.
///
/// Pure `StateCoordinator` state: the frame→screen resolution is
/// KiwiCore's (it needs `NSScreen` and the AX/AppKit y-flip),
/// mirrored into the fold as `arrivalDisplay` — the seam these
/// tests drive directly, so nothing here reaches a real screen.
@Suite("Cross-screen arrival home (#1010)")
struct ArrivalScreenHomeTests {
    private let displayA = DisplayID(1)
    private let displayB = DisplayID(2)
    private let mover = WindowID(11)

    /// Spaces 1–2 on the main screen, space 5 on the second one,
    /// with the main screen focused and showing space 1 — the
    /// reported two-screen layout. The second screen sits at a
    /// negative y like the verifying machine's, which no pure
    /// state read touches: it is the flip that would have made a
    /// frame comparison silently wrong here.
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
        state.workspaces.assign(SpaceID("1"), to: displayA)
        state.workspaces.assign(SpaceID("2"), to: displayA)
        state.workspaces.assign(SpaceID("5"), to: displayB)
        state.workspaces.activate(SpaceID("1"))
        return state
    }

    private func window(
        _ id: WindowID = WindowID(11),
        bundleID: String? = nil
    ) -> ManagedWindow {
        ManagedWindow(
            id: id,
            pid: 100,
            appName: "TextEdit",
            appBundleID: bundleID,
            title: "Doc"
        )
    }

    /// Lands `mover` in `space`, then departs it the way a
    /// Desktop move does — a non-minimized destroy, which is
    /// what writes the remembered space.
    private func depart(
        _ state: inout StateCoordinator,
        from space: SpaceID
    ) {
        state.workspaces.activate(space)
        state.apply(.windowCreated(window()))
        #expect(state.workspaces.space(of: mover) == space)
        state.apply(
            .windowDestroyed(mover, wasMinimized: false)
        )
    }

    @Test("A cross-screen arrival joins its screen's space")
    func crossScreenArrivalTakesItsScreensSpace() {
        var state = twoScreens()
        depart(&state, from: SpaceID("1"))
        // Revealed on the second screen: the frame resolved to
        // display B, its remembered space 1 lays out on A.
        state.arrivalDisplay = displayB
        let effects = state.apply(.windowCreated(window()))
        #expect(state.workspaces.space(of: mover) == SpaceID("5"))
        #expect(effects.rehomedToScreenSpace == SpaceID("5"))
        // Homed, not duplicated: the flat array of the space it
        // remembered keeps no slot for it.
        #expect(
            state.workspaces[SpaceID("1")]?.windows.contains(mover)
                == false
        )
    }

    @Test("A same-screen arrival keeps its remembered space")
    func sameScreenArrivalKeepsItsRememberedSpace() {
        var state = twoScreens()
        // Space 2 lives on the main screen but is NOT the space
        // that screen shows: the rule keys on the DISPLAY, never
        // on visibility, so the remembered space still wins.
        depart(&state, from: SpaceID("2"))
        state.workspaces.activate(SpaceID("1"))
        state.arrivalDisplay = displayA
        let effects = state.apply(.windowCreated(window()))
        #expect(state.workspaces.space(of: mover) == SpaceID("2"))
        #expect(effects.rehomedToScreenSpace == nil)
    }

    @Test("A single screen resolves exactly as it did before")
    func singleScreenIsUntouched() {
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
        state.workspaces.ensureSpace(SpaceID("2"))
        state.workspaces.assign(SpaceID("1"), to: displayA)
        state.workspaces.assign(SpaceID("2"), to: displayA)
        depart(&state, from: SpaceID("2"))
        state.workspaces.activate(SpaceID("1"))
        state.arrivalDisplay = displayA
        let effects = state.apply(.windowCreated(window()))
        #expect(state.workspaces.space(of: mover) == SpaceID("2"))
        #expect(effects.rehomedToScreenSpace == nil)
    }

    @Test("An unresolvable arrival screen changes nothing")
    func noArrivalDisplayChangesNothing() {
        var state = twoScreens()
        depart(&state, from: SpaceID("1"))
        state.workspaces.activate(SpaceID("5"))
        // No screen backs the frame (the stash corner, a display
        // mid-detach): resolve as before rather than guessing.
        state.arrivalDisplay = nil
        let effects = state.apply(.windowCreated(window()))
        #expect(state.workspaces.space(of: mover) == SpaceID("1"))
        #expect(effects.rehomedToScreenSpace == nil)
    }

    @Test("A fresh window is not re-homed by its screen")
    func aFreshArrivalIsUnaffected() {
        var state = twoScreens()
        // Never departed, so nothing was remembered: this is a
        // placement the user never contradicted, and it lands in
        // the active space as always — even though its frame
        // resolved to the other screen.
        state.arrivalDisplay = displayB
        let effects = state.apply(.windowCreated(window()))
        #expect(state.workspaces.space(of: mover) == SpaceID("1"))
        #expect(effects.rehomedToScreenSpace == nil)
    }

    @Test("An app rule's target is not overridden by the screen")
    func anAppRuleTargetSurvives() {
        var state = twoScreens()
        state.appRules["com.apple.textedit"] = SpaceID("2")
        state.arrivalDisplay = displayB
        let effects = state.apply(
            .windowCreated(
                window(bundleID: "com.apple.textedit")
            )
        )
        #expect(state.workspaces.space(of: mover) == SpaceID("2"))
        #expect(effects.rehomedToScreenSpace == nil)
    }

    @Test("A remembered space with no display is left alone")
    func unassignedRememberedSpaceIsLeftAlone() {
        var state = twoScreens()
        depart(&state, from: SpaceID("1"))
        // The remembered space's display went away (a detach,
        // early boot before assignment): with no display there is
        // nothing for the arrival's screen to disagree with, so
        // it resolves as before.
        state.workspaces.removeDisplay(displayA)
        state.arrivalDisplay = displayB
        let effects = state.apply(.windowCreated(window()))
        #expect(state.workspaces.space(of: mover) == SpaceID("1"))
        #expect(effects.rehomedToScreenSpace == nil)
    }

    @Test("A screen showing nothing keeps the remembered space")
    func arrivalScreenShowingNothingKeepsRemembered() {
        var state = twoScreens()
        depart(&state, from: SpaceID("1"))
        // A third screen, freshly attached, with no space of its
        // own yet: there is no home to prefer, so the remembered
        // one stands rather than the window landing nowhere.
        let displayC = DisplayID(3)
        state.workspaces.upsertDisplay(
            Display(
                id: displayC,
                name: "Third",
                frame: CGRect(
                    x: -1920,
                    y: 0,
                    width: 1920,
                    height: 1080
                )
            )
        )
        state.arrivalDisplay = displayC
        let effects = state.apply(.windowCreated(window()))
        #expect(state.workspaces.space(of: mover) == SpaceID("1"))
        #expect(effects.rehomedToScreenSpace == nil)
    }

    @Test("A re-homed arrival does not steal its screen's focus")
    func rehomedArrivalDoesNotStealFocus() {
        var state = twoScreens()
        depart(&state, from: SpaceID("1"))
        // A window already focused in the space the second screen
        // shows: the returner joins without taking the ring
        // (#636) — being re-homed does not make it a fresh spawn.
        state.workspaces.activate(SpaceID("5"))
        state.apply(.windowCreated(window(WindowID(22))))
        state.workspaces.activate(SpaceID("1"))
        state.arrivalDisplay = displayB
        state.apply(.windowCreated(window()))
        #expect(state.workspaces.space(of: mover) == SpaceID("5"))
        #expect(
            state.workspaces[SpaceID("5")]?.focused
                == WindowID(22)
        )
    }
}
