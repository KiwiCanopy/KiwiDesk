import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A local sticky is a tiled member of its home Space whenever
/// that home is the active Space, whatever its scope (#1301).
///
/// `resize()` resolves against `activeSpace.focused`, and the
/// `.windowFocused` fold writes `focused` on the MEMBERSHIP
/// Space, so a clickless focus of a sticky (⌘Tab, the Dock)
/// lands `home.focused = sticky` without moving `activeSpace`.
/// The tiled resize paths fall back to a neighbour-moving write
/// for a focus their partition does not hold, so what keeps
/// that press off the neighbours is this: `stickyRenderSpace`
/// answers `activeSpace` for `.global` and
/// `activeSpace(on: homeDisplay)` for `.display`, and
/// `activeSpace(on:)` prefers the active Space when it lives on
/// that display — so an ACTIVE home never drops its own sticky
/// from `effectiveTiledMembers`. The writers' `tiled.contains`
/// guard is a construction net for that focus, not a served
/// case; a derivation change that lets an active home drop a
/// local sticky reopens #1301's press and reds here.
///
/// Pure `StateCoordinator` state; no AX / screen needed.
@Suite("Active home sticky membership")
struct ActiveHomeStickyMembershipTests {
    private static let sticky = WindowID(1)
    private static let displayA = DisplayID(1)
    private static let displayB = DisplayID(2)

    /// Spaces 1–2 on display A, space 5 on display B. A tiled
    /// sticky (id 1) of the given scope homed on space 2 beside
    /// a plain local (id 2); a plain local (id 9) on space 5.
    /// The home is the SECOND Space on its display on purpose:
    /// `activeSpace(on:)` falls through to the display's first
    /// Space, so a home that is first would be answered by the
    /// fallback and mask the active-Space branch this suite
    /// pins (guard-prover, 2026-09-14).
    private func twoMonitorState(
        scope: StickyScope
    ) -> StateCoordinator {
        var state = StateCoordinator()
        state.workspaces.upsertDisplay(
            Display(
                id: Self.displayA,
                name: "A",
                frame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
            )
        )
        state.workspaces.upsertDisplay(
            Display(
                id: Self.displayB,
                name: "B",
                frame: CGRect(
                    x: 1920,
                    y: 0,
                    width: 1920,
                    height: 1080
                )
            )
        )
        for id in ["1", "2", "5"] {
            state.workspaces.ensureSpace(SpaceID(id))
        }
        state.workspaces.assign(SpaceID("1"), to: Self.displayA)
        state.workspaces.assign(SpaceID("2"), to: Self.displayA)
        state.workspaces.assign(SpaceID("5"), to: Self.displayB)
        state.windows.upsert(
            ManagedWindow(
                id: Self.sticky,
                pid: 1,
                appName: "Sticky",
                stickyScope: scope
            )
        )
        state.workspaces.add(Self.sticky, to: SpaceID("2"))
        state.windows.upsert(
            ManagedWindow(id: WindowID(2), pid: 2, appName: "Local")
        )
        state.workspaces.add(WindowID(2), to: SpaceID("2"))
        state.windows.upsert(
            ManagedWindow(id: WindowID(9), pid: 9, appName: "Plain")
        )
        state.workspaces.add(WindowID(9), to: SpaceID("5"))
        return state
    }

    private func homeTiled(_ state: StateCoordinator) -> [WindowID] {
        state.effectiveTiledMembers(of: state.workspaces[SpaceID("2")]!)
    }

    @Test(
        "An active home keeps its sticky, from every prior focus",
        arguments: [StickyScope.global, .display]
    )
    func activeHomeKeepsItsSticky(scope: StickyScope) {
        // Reach the active home from each Space the focus can
        // come back from — the same display, the other display,
        // and the other display while the home display shows
        // another Space (#1230's secondary-screen switch) — so
        // no stale per-display pick outranks the active Space.
        for prior in ["2", "1", "5"] {
            var state = twoMonitorState(scope: scope)
            state.workspaces.activate(SpaceID(prior))
            if prior == "5" {
                state.workspaces.show(SpaceID("1"), on: Self.displayA)
            }
            state.workspaces.activate(SpaceID("2"))
            let window = state.windows[Self.sticky]!
            #expect(state.stickyRenderSpace(of: window) == "2")
            #expect(homeTiled(state) == [Self.sticky, WindowID(2)])
        }
    }

    @Test("The drop exists only while the home is NOT active")
    func hiddenHomeDropsItsSticky() {
        // The control the positive needs: the derivation still
        // drops an elsewhere-rendering sticky at all, so the
        // clause above is not green by a filter that stopped
        // filtering. Global: the focus on B is where it renders.
        var global = twoMonitorState(scope: .global)
        global.workspaces.activate(SpaceID("5"))
        #expect(homeTiled(global) == [WindowID(2)])
        // Display: the home display showing another Space while
        // B holds the focus.
        var display = twoMonitorState(scope: .display)
        display.workspaces.activate(SpaceID("5"))
        display.workspaces.show(SpaceID("1"), on: Self.displayA)
        #expect(homeTiled(display) == [WindowID(2)])
        // And with the home display simply switched away.
        var switched = twoMonitorState(scope: .display)
        switched.workspaces.activate(SpaceID("1"))
        #expect(homeTiled(switched) == [WindowID(2)])
    }
}
