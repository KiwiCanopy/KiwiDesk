import Foundation
import Testing

@testable import KiwiDeskCore

/// #637: a repeat press of Open or Focus (`pull_or_spawn`)
/// while one of the app's windows is already focused advances
/// to the app's next tracked window — space order then slot
/// order, wrapping — instead of re-activating. The cycle reads
/// tracked state plus the injected frontmost seam only, so the
/// guards are fully assertable here; the fallback (activate /
/// launch) needs the real workspace and stays out of reach.
@MainActor
@Suite("Open-or-focus window cycling (#637)", .serialized)
struct OpenOrFocusCycleTests {

    private static let bundle = "app.test.100"

    private func makeCore() -> KiwiCore {
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 875)
        }
        // The ring assertions below reason from the shipped
        // default — focused-only rings; pin it (tests.md).
        #expect(
            !core.tiler.settings.borderStyle.unfocusedEnabled
        )
        return core
    }

    private func addWindow(
        _ core: KiwiCore,
        _ id: UInt32,
        pid: pid_t = 100,
        space: SpaceID = "1",
        sticky: Bool = false,
        overlay: Bool = false
    ) {
        core.state.windows.upsert(
            ManagedWindow(
                id: WindowID(id),
                pid: pid,
                appName: "App\(pid)",
                appBundleID: pid == 100
                    ? Self.bundle : "app.test.\(pid)",
                stickyScope: sticky ? .global : .none,
                isTransientOverlay: overlay
            )
        )
        core.state.workspaces.ensureSpace(space)
        core.state.workspaces.add(WindowID(id), to: space)
    }

    /// The ring the specs grant `id`, if any.
    private func ring(
        _ core: KiwiCore,
        _ id: UInt32
    ) -> BorderManager.Spec? {
        core.desiredBorderSpecs().first {
            $0.window == WindowID(id)
        }
    }

    private func press(_ core: KiwiCore) -> CommandResponse {
        core.execute(
            "pull_or_spawn",
            args: [.string(Self.bundle)]
        )
    }

    @Test("Repeat press advances to the app's next window")
    func advancesToNextWindow() {
        let core = makeCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        addWindow(core, 20)
        addWindow(core, 21)
        addWindow(core, 30, pid: 300)
        core.state.workspaces.focus(WindowID(20), in: "1")
        core.frontmostPIDProvider = { 100 }
        #expect(press(core).isSuccess)
        #expect(
            core.state.workspaces.lastFocused == WindowID(21)
        )
        let focused = core.tiler.settings.borderStyle.focusedColor
        #expect(ring(core, 21)?.colorHex == focused)
        #expect(ring(core, 20) == nil)
    }

    @Test("The cycle wraps from the last window to the first")
    func wrapsAround() {
        let core = makeCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        addWindow(core, 20)
        addWindow(core, 21)
        core.state.workspaces.focus(WindowID(21), in: "1")
        core.frontmostPIDProvider = { 100 }
        #expect(press(core).isSuccess)
        #expect(
            core.state.workspaces.lastFocused == WindowID(20)
        )
    }

    @Test("A successor on another space switches and focuses")
    func crossSpaceSuccessorSwitches() {
        let core = makeCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.ensureSpace("2")
        core.state.workspaces.activate("1")
        addWindow(core, 20)
        addWindow(core, 21, space: "2")
        core.state.workspaces.focus(WindowID(20), in: "1")
        core.frontmostPIDProvider = { 100 }
        #expect(press(core).isSuccess)
        #expect(core.state.workspaces.activeSpace == "2")
        #expect(
            core.state.workspaces.lastFocused == WindowID(21)
        )
        // The ring rides the switch (#636's regression class).
        let focused = core.tiler.settings.borderStyle.focusedColor
        #expect(ring(core, 21)?.colorHex == focused)
    }

    /// A sticky successor is visible right here (#414): its
    /// membership names only its hidden home space, so the
    /// cycle must focus it in place, never fly to its home.
    @Test("A sticky successor focuses without a space switch")
    func stickySuccessorStaysPut() {
        let core = makeCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.ensureSpace("2")
        core.state.workspaces.activate("1")
        addWindow(core, 20)
        addWindow(core, 21, space: "2", sticky: true)
        core.state.workspaces.focus(WindowID(20), in: "1")
        core.frontmostPIDProvider = { 100 }
        #expect(press(core).isSuccess)
        #expect(core.state.workspaces.activeSpace == "1")
        #expect(
            core.state.workspaces.lastFocused == WindowID(21)
        )
    }

    /// A transient overlay (a launcher's panel, #300) is
    /// tracked but momentary — never part of the ring.
    @Test("A transient overlay never joins the cycle")
    func overlayNeverJoinsTheCycle() {
        let core = makeCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        addWindow(core, 20)
        addWindow(core, 21, overlay: true)
        core.state.workspaces.focus(WindowID(20), in: "1")
        core.frontmostPIDProvider = { 100 }
        #expect(!core.cycleToNextWindow(bundleID: Self.bundle))
        #expect(
            core.state.workspaces.lastFocused == WindowID(20)
        )
    }

    @Test("Repeat presses walk spaces then slots, then wrap")
    func walksStableRingAcrossSpaces() {
        let core = makeCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.ensureSpace("2")
        core.state.workspaces.activate("1")
        addWindow(core, 20)
        addWindow(core, 21, space: "2")
        addWindow(core, 22, space: "2")
        core.state.workspaces.focus(WindowID(20), in: "1")
        core.frontmostPIDProvider = { 100 }
        var visited: [WindowID?] = []
        for _ in 0..<3 {
            #expect(press(core).isSuccess)
            visited.append(core.state.workspaces.lastFocused)
        }
        #expect(
            visited == [WindowID(21), WindowID(22), WindowID(20)]
        )
    }

    @Test("Another frontmost app falls through to activate")
    func staleFocusFallsThrough() {
        let core = makeCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        addWindow(core, 20)
        addWindow(core, 21)
        core.state.workspaces.focus(WindowID(20), in: "1")
        // State says our window is focused; the OS says another
        // app is forward — the press must pull, not cycle.
        core.frontmostPIDProvider = { 999 }
        #expect(!core.cycleToNextWindow(bundleID: Self.bundle))
        #expect(
            core.state.workspaces.lastFocused == WindowID(20)
        )
    }

    @Test("Another app's focus falls through to activate")
    func otherAppFocusFallsThrough() {
        let core = makeCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        addWindow(core, 20)
        addWindow(core, 21)
        addWindow(core, 30, pid: 300)
        core.state.workspaces.focus(WindowID(30), in: "1")
        core.frontmostPIDProvider = { 300 }
        #expect(!core.cycleToNextWindow(bundleID: Self.bundle))
        #expect(
            core.state.workspaces.lastFocused == WindowID(30)
        )
    }

    @Test("A single window never cycles")
    func singleWindowNeverCycles() {
        let core = makeCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        addWindow(core, 20)
        core.state.workspaces.focus(WindowID(20), in: "1")
        core.frontmostPIDProvider = { 100 }
        #expect(!core.cycleToNextWindow(bundleID: Self.bundle))
        #expect(
            core.state.workspaces.lastFocused == WindowID(20)
        )
    }
}
