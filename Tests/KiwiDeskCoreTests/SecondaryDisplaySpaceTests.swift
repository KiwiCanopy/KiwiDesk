import Foundation
import Testing

@testable import KiwiDeskCore

/// A swipe on a SECONDARY display moves that display's Space
/// (#1230, ruling 3) — while the profile still stands down,
/// which stays the main screen's (#888).
///
/// Measured 2026-09-04 on two screens before this existed: a
/// secondary swipe emitted `desktop_change` for that monitor and
/// nothing else, so the screen kept showing the Space its
/// PREVIOUS Desktop had. That is the confusion #1230 removes, one
/// screen over.
///
/// The decision is asserted directly rather than through
/// `handleDesktopChange`, whose arm also retiles — a retile is
/// only observable on a host with a screen, which is the same
/// reason `SecondarySwitchTests` asserts `isSecondarySwitch`
/// rather than driving the handler.
@Suite("Secondary-display Space movement (#1230)", .serialized)
@MainActor
struct SecondaryDisplaySpaceTests {
    /// Two screens, two Spaces each: 1 and 2 on display A, 3 and
    /// 4 on display B. Desktops 1–2 are A's (spaces 10, 11) and
    /// 3–4 are B's (spaces 20, 21).
    private func makeCore() -> KiwiCore {
        let core = makeAuthorityCore()
        connectAuthority(
            core,
            [
                authorityDisplay(1, "A"),
                authorityDisplay(2, "B", x: 100),
            ]
        )
        pinTwoDisplays()
        for id in [SpaceID(1), SpaceID(2)] {
            core.state.workspaces.ensureSpace(id)
            core.state.workspaces.assign(id, to: DisplayID(1))
        }
        for id in [SpaceID(3), SpaceID(4)] {
            core.state.workspaces.ensureSpace(id)
            core.state.workspaces.assign(id, to: DisplayID(2))
        }
        core.state.workspaces.activate(SpaceID(1))
        return core
    }

    private func snapshot(secondaryCurrent: UInt64) -> DesktopSnapshot {
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: secondaryCurrent
        )
        return NativeSpaces.desktopSnapshot()
    }

    /// The arriving Desktop has no memory, so it takes a Space of
    /// its own from the ones that lay out on ITS screen.
    @Test("A secondary switch moves that display's Space")
    func secondarySwitchMovesItsOwnSpace() {
        defer { resetAuthorityOverrides() }
        let core = makeCore()
        // Display B shows Space 3 while on its first Desktop.
        core.state.workspaces.show(SpaceID(3), on: DisplayID(2))
        let arriving = snapshot(secondaryCurrent: 21)
        core.moveSwitchedDisplaySpaces(
            DisplaySwitch(
                changed: ["UUID-B"],
                previous: ["UUID-A": 10, "UUID-B": 20]
            ),
            in: arriving
        )
        #expect(
            core.state.workspaces.activeSpace(on: DisplayID(2))
                == SpaceID(4)
        )
        // The main screen is untouched.
        #expect(core.state.workspaces.activeSpace == SpaceID(1))
    }

    /// The Space it was showing is filed under the Desktop it
    /// LEFT, resolved from the reading the diff carried — so
    /// coming back returns to it.
    @Test("The departing Desktop remembers what it showed")
    func departingDesktopIsRemembered() {
        defer { resetAuthorityOverrides() }
        let core = makeCore()
        core.state.workspaces.show(SpaceID(4), on: DisplayID(2))
        let arriving = snapshot(secondaryCurrent: 21)
        core.moveSwitchedDisplaySpaces(
            DisplaySwitch(
                changed: ["UUID-B"],
                previous: ["UUID-A": 10, "UUID-B": 20]
            ),
            in: arriving
        )
        let left = arriving.key(of: 20)
        #expect(left != nil)
        #expect(
            left.flatMap { core.desktopMemory.virtualSpaces[$0] }
                == SpaceID(4)
        )
    }

    /// It picks among the Spaces on ITS screen. Space 1 and 2 lay
    /// out on the main display, so a free one there is not a
    /// candidate — showing it would put one Space on two screens.
    @Test("A display picks only from its own Spaces")
    func picksOnlyItsOwnDisplaysSpaces() {
        defer { resetAuthorityOverrides() }
        let core = makeCore()
        let arriving = snapshot(secondaryCurrent: 21)
        core.moveSwitchedDisplaySpaces(
            DisplaySwitch(
                changed: ["UUID-B"],
                previous: ["UUID-A": 10, "UUID-B": 20]
            ),
            in: arriving
        )
        let shown = core.state.workspaces.activeSpace(
            on: DisplayID(2)
        )
        #expect(shown == SpaceID(3) || shown == SpaceID(4))
    }

    /// The MAIN display is not this arm's business: its Space is
    /// moved by the handler's own branch, and moving it here too
    /// would activate twice per switch.
    @Test("The main display is skipped")
    func mainDisplayIsSkipped() {
        defer { resetAuthorityOverrides() }
        let core = makeCore()
        let arriving = snapshot(secondaryCurrent: 20)
        core.moveSwitchedDisplaySpaces(
            DisplaySwitch(
                changed: ["UUID-A"],
                previous: ["UUID-A": 11, "UUID-B": 20]
            ),
            in: arriving
        )
        #expect(core.state.workspaces.activeSpace == SpaceID(1))
    }

    /// Swiping the display that holds the ACTIVE Space moves it
    /// rather than writing `secondaryShown` — the map's own
    /// invariant is that the active display is never a key there.
    @Test("Swiping the focused screen moves the active Space")
    func focusedScreenMovesTheActiveSpace() {
        defer { resetAuthorityOverrides() }
        let core = makeCore()
        // Focus sits on display B.
        core.state.workspaces.activate(SpaceID(3))
        #expect(core.state.workspaces.activeSpace == SpaceID(3))
        let arriving = snapshot(secondaryCurrent: 21)
        core.moveSwitchedDisplaySpaces(
            DisplaySwitch(
                changed: ["UUID-B"],
                previous: ["UUID-A": 10, "UUID-B": 20]
            ),
            in: arriving
        )
        #expect(core.state.workspaces.activeSpace == SpaceID(4))
        #expect(
            core.state.workspaces.secondaryShown[DisplayID(2)]
                == nil
        )
    }

    /// A Space that does not live on the display is refused, and
    /// the assertion reads `secondaryShown` ITSELF rather than
    /// what `activeSpace(on:)` answers.
    ///
    /// The reader has its own self-healing clause — it ignores an
    /// entry whose Space moved away — so asserting through it
    /// passes whether or not `show` guards, which is what the
    /// first draft of this test did. What the guard actually
    /// prevents is a STRANDED entry: exactly what
    /// `assign(_:to:)`'s filter exists to drop, and what
    /// `WorkspaceMapSealTests` names as the harm of a stray
    /// write.
    @Test("A foreign Space strands no entry on a display")
    func foreignSpaceStrandsNothing() {
        defer { resetAuthorityOverrides() }
        let core = makeCore()
        core.state.workspaces.show(SpaceID(3), on: DisplayID(2))
        // Space 1 lays out on display A.
        core.state.workspaces.show(SpaceID(1), on: DisplayID(2))
        #expect(
            core.state.workspaces.secondaryShown[DisplayID(2)]
                == SpaceID(3)
        )
    }
}
