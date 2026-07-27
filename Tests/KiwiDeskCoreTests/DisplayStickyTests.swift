import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Display-sticky rendering (#445): a `.display` sticky window is
/// present on every space of ONE monitor — its home space's
/// display — and never travels to another monitor. Pure
/// `StateCoordinator` state; no AX / screen needed.
@Suite("Display sticky rendering")
struct DisplayStickyRenderTests {
    private let displayA = DisplayID(1)
    private let displayB = DisplayID(2)

    /// Spaces 1–2 on display A, space 5 on display B; A focused.
    /// A `.display` sticky window (id 1) homed on space 1, plus a
    /// plain local window (id 9) on space 5.
    private func twoMonitorState() -> StateCoordinator {
        var state = StateCoordinator()
        state.workspaces.upsertDisplay(
            Display(
                id: displayA,
                name: "A",
                frame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
            )
        )
        state.workspaces.upsertDisplay(
            Display(
                id: displayB,
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
        state.workspaces.assign(SpaceID("1"), to: displayA)
        state.workspaces.assign(SpaceID("2"), to: displayA)
        state.workspaces.assign(SpaceID("5"), to: displayB)
        state.workspaces.activate(SpaceID("1"))
        state.windows.upsert(
            ManagedWindow(
                id: WindowID(1),
                pid: 1,
                appName: "Sticky",
                stickyScope: .display
            )
        )
        state.workspaces.add(WindowID(1), to: SpaceID("1"))
        state.windows.upsert(
            ManagedWindow(id: WindowID(9), pid: 9, appName: "Plain")
        )
        state.workspaces.add(WindowID(9), to: SpaceID("5"))
        return state
    }

    @Test("Renders on its home display's shown space, home active")
    func rendersOnHomeShown() {
        let state = twoMonitorState()
        let window = state.windows[WindowID(1)]!
        // Home space 1 is shown on display A, so it renders there.
        #expect(
            state.stickyRenderSpace(of: window, focused: "1") == "1"
        )
    }

    @Test("Never travels to another monitor's space")
    func noTravelToOtherDisplay() {
        let state = twoMonitorState()
        // Display B shows space 5; the display sticky lives on A,
        // so B's layout must not inject it.
        let s5 = state.workspaces[SpaceID("5")]!
        let tiled = state.effectiveTiledMembers(
            of: s5,
            activeSpace: "1"
        )
        #expect(!tiled.contains(WindowID(1)))
        #expect(tiled == [WindowID(9)])
    }

    @Test("Follows its home display when that display switches space")
    func followsHomeDisplaySpace() {
        var state = twoMonitorState()
        // Switch display A to space 2: the display sticky's home
        // space 1 is now hidden, so it travels into space 2 — the
        // shown space on ITS display — but still not to B's space 5.
        state.workspaces.activate(SpaceID("2"))
        let window = state.windows[WindowID(1)]!
        #expect(
            state.stickyRenderSpace(of: window, focused: "2") == "2"
        )
        let s2 = state.workspaces[SpaceID("2")]!
        #expect(
            state.effectiveTiledMembers(of: s2, activeSpace: "2")
                .contains(WindowID(1))
        )
        let s5 = state.workspaces[SpaceID("5")]!
        #expect(
            !state.effectiveTiledMembers(of: s5, activeSpace: "2")
                .contains(WindowID(1))
        )
    }

    @Test("A global sticky renders on the focused display instead")
    func globalRendersOnFocused() {
        var state = twoMonitorState()
        state.windows.setSticky(WindowID(1), .global)
        var window = state.windows[WindowID(1)]!
        // Home space 1 is focused → renders on 1.
        #expect(
            state.stickyRenderSpace(of: window, focused: "1") == "1"
        )
        // Focus display B (space 5): a GLOBAL sticky follows the
        // focused display, so its render space becomes 5 — unlike
        // the display sticky, which stayed on A.
        state.workspaces.activate(SpaceID("5"))
        window = state.windows[WindowID(1)]!
        #expect(
            state.stickyRenderSpace(of: window, focused: "5") == "5"
        )
    }
}

/// The sticky `move_to_space` guard (#445): a global sticky
/// refuses any move, a display sticky refuses a same-display
/// target but accepts a cross-display one (which re-homes it).
@Suite("Sticky move guard", .serialized)
@MainActor
struct StickyMoveGuardTests {
    private let displayA = DisplayID(1)
    private let displayB = DisplayID(2)

    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-move-\(UUID().uuidString)"
                )
        )
    }

    /// Two monitors, spaces 1–2 on A and 5 on B, one window on
    /// space 1 with the given scope.
    private func seed(_ core: KiwiCore, scope: StickyScope) {
        core.state.workspaces.upsertDisplay(
            Display(
                id: displayA,
                name: "A",
                frame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
            )
        )
        core.state.workspaces.upsertDisplay(
            Display(
                id: displayB,
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
            core.state.workspaces.ensureSpace(SpaceID(id))
        }
        core.state.workspaces.assign(SpaceID("1"), to: displayA)
        core.state.workspaces.assign(SpaceID("2"), to: displayA)
        core.state.workspaces.assign(SpaceID("5"), to: displayB)
        core.state.workspaces.activate(SpaceID("1"))
        core.state.windows.upsert(
            ManagedWindow(
                id: WindowID(1),
                pid: 1,
                appName: "App",
                stickyScope: scope
            )
        )
        core.state.workspaces.add(WindowID(1), to: SpaceID("1"))
    }

    @Test("A global sticky refuses any move_to_space")
    func globalRefusesAll() {
        let core = makeCore()
        seed(core, scope: .global)
        core.moveWindow(WindowID(1), to: SpaceID("2"), follow: false)
        // Same display, other display — refused either way.
        #expect(core.state.workspaces.space(of: WindowID(1)) == "1")
        core.moveWindow(WindowID(1), to: SpaceID("5"), follow: false)
        #expect(core.state.workspaces.space(of: WindowID(1)) == "1")
    }

    @Test("A display sticky refuses a same-display target")
    func displayRefusesSameDisplay() {
        let core = makeCore()
        seed(core, scope: .display)
        // Space 2 is on the same monitor (A) as home space 1.
        core.moveWindow(WindowID(1), to: SpaceID("2"), follow: false)
        #expect(core.state.workspaces.space(of: WindowID(1)) == "1")
    }

    @Test("A display sticky accepts a cross-display target, re-homes")
    func displayAllowsCrossDisplay() {
        let core = makeCore()
        seed(core, scope: .display)
        // Space 5 is on the other monitor (B) — allowed, re-homes.
        core.moveWindow(WindowID(1), to: SpaceID("5"), follow: false)
        #expect(core.state.workspaces.space(of: WindowID(1)) == "5")
        // Still a display sticky, now homed on display B.
        #expect(
            core.state.windows[WindowID(1)]?.stickyScope == .display
        )
    }

    /// The Space-Bar spring is a SECOND re-home path (#372) that
    /// does not go through `moveWindow`; the #445 guard must gate it
    /// too, or a dragged sticky re-homes silently (review finding).
    @Test("The Space-Bar spring path honours the display guard")
    func springHonoursDisplayGuard() {
        let core = makeCore()
        seed(core, scope: .display)
        core.wireSpaceBarDrop()
        // Spring onto a same-display space is refused: it reports
        // false (so `fire` records no `sprungSpace`), no re-home,
        // and no visible space switch happened.
        #expect(!core.spaceBarDrop.spring(SpaceID("2"), WindowID(1)))
        #expect(core.state.workspaces.space(of: WindowID(1)) == "1")
        #expect(core.state.workspaces.activeSpace == "1")
        // A cross-display spring is allowed, matching moveWindow —
        // it reports true.
        #expect(core.spaceBarDrop.spring(SpaceID("5"), WindowID(1)))
        #expect(core.state.workspaces.space(of: WindowID(1)) == "5")
    }

    @Test("The Space-Bar spring path refuses a global sticky")
    func springRefusesGlobal() {
        let core = makeCore()
        seed(core, scope: .global)
        core.wireSpaceBarDrop()
        #expect(!core.spaceBarDrop.spring(SpaceID("2"), WindowID(1)))
        #expect(!core.spaceBarDrop.spring(SpaceID("5"), WindowID(1)))
        #expect(core.state.workspaces.space(of: WindowID(1)) == "1")
        #expect(core.state.workspaces.activeSpace == "1")
    }

    @Test("On a single monitor a display sticky refuses like global")
    func singleMonitorDisplayRefuses() {
        let core = makeCore()
        // No displays assigned → display scope collapses to global,
        // so every same-"display" (nil) target is refused.
        core.state.workspaces.ensureSpace(SpaceID("1"))
        core.state.workspaces.ensureSpace(SpaceID("2"))
        core.state.workspaces.activate(SpaceID("1"))
        core.state.windows.upsert(
            ManagedWindow(
                id: WindowID(1),
                pid: 1,
                appName: "App",
                stickyScope: .display
            )
        )
        core.state.workspaces.add(WindowID(1), to: SpaceID("1"))
        core.moveWindow(WindowID(1), to: SpaceID("2"), follow: false)
        #expect(core.state.workspaces.space(of: WindowID(1)) == "1")
    }
}
