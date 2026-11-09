import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `focus_app_window` (#3131) steps the frontmost app's ring —
/// the one Open or Focus's repeat press walks (#637) — either
/// way: Space order, then slot order, wrapping. Minimized
/// windows are not in it and stay minimized (#673). The away
/// reach is `FocusAppWindowReachTests`'.
@MainActor
@Suite("Focus app window (#3131)", .serialized)
struct FocusAppWindowTests {
    private static let bundle = "app.test.100"

    /// Windows 20 in Space 1, 21 and 22 in Space 2, and another
    /// app's 30 in Space 1; 20 focused, app 100 frontmost.
    private func makeCore() -> KiwiCore {
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 875)
        }
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.ensureSpace("2")
        core.state.workspaces.activate("1")
        addWindow(core, 20, space: "1")
        addWindow(core, 30, pid: 300, space: "1")
        addWindow(core, 21, space: "2")
        addWindow(core, 22, space: "2")
        core.state.workspaces.focus(WindowID(20), in: "1")
        core.frontmostPIDProvider = { 100 }
        return core
    }

    private func addWindow(
        _ core: KiwiCore,
        _ id: UInt32,
        pid: pid_t = 100,
        space: SpaceID
    ) {
        core.state.windows.upsert(
            ManagedWindow(
                id: WindowID(id),
                pid: pid,
                appName: "App\(pid)",
                appBundleID: pid == 100
                    ? Self.bundle : "app.test.\(pid)"
            )
        )
        core.state.workspaces.add(WindowID(id), to: space)
    }

    private func step(
        _ core: KiwiCore,
        _ direction: String
    ) -> CommandResponse {
        core.execute("focus_app_window", args: [.string(direction)])
    }

    private func walk(
        _ core: KiwiCore,
        _ direction: String,
        times: Int
    ) -> [WindowID?] {
        (0..<times).map { _ in
            #expect(step(core, direction).isSuccess)
            return core.state.workspaces.lastFocused
        }
    }

    @Test("next walks Spaces then slots, then wraps")
    func nextWalksTheRing() {
        let core = makeCore()
        #expect(
            walk(core, "next", times: 3)
                == [WindowID(21), WindowID(22), WindowID(20)]
        )
        #expect(core.state.workspaces.activeSpace == "1")
    }

    @Test("prev walks the ring backwards, wrapping")
    func prevWalksBackwards() {
        let core = makeCore()
        #expect(
            walk(core, "prev", times: 3)
                == [WindowID(22), WindowID(21), WindowID(20)]
        )
    }

    @Test("A step onto another Space switches to it")
    func crossSpaceStepSwitches() {
        let core = makeCore()
        #expect(step(core, "prev").isSuccess)
        #expect(core.state.workspaces.activeSpace == "2")
        #expect(core.state.workspaces.lastFocused == WindowID(22))
    }

    /// A minimize folds the window out of state (#673), so the
    /// ring steps over it and nothing restores it.
    @Test("A minimized window is skipped and stays minimized")
    func minimizedIsSkipped() {
        let core = makeCore()
        var restored: [WindowID] = []
        core.openOrFocus.deminiaturize = { _, id in
            restored.append(id)
        }
        core.state.apply(
            .windowDestroyed(WindowID(21), wasMinimized: true)
        )
        #expect(
            core.state.lastMinimized(bundleID: Self.bundle)
                == WindowID(21)
        )
        #expect(
            walk(core, "next", times: 2)
                == [WindowID(22), WindowID(20)]
        )
        #expect(restored.isEmpty)
        #expect(core.state.windows[WindowID(21)] == nil)
    }

    /// Every other window minimized: the press is refused, not
    /// answered by un-minimizing one the way Open or Focus's
    /// first press does (#673).
    @Test("Other windows all minimized: refused, none restored")
    func allOthersMinimizedRefuses() {
        let core = makeCore()
        var restored: [WindowID] = []
        core.openOrFocus.deminiaturize = { _, id in
            restored.append(id)
        }
        for id: UInt32 in [21, 22] {
            core.state.apply(
                .windowDestroyed(WindowID(id), wasMinimized: true)
            )
        }
        #expect(
            step(core, "next")
                == .fail("the focused app has no other window to focus")
        )
        #expect(restored.isEmpty)
        #expect(core.state.workspaces.lastFocused == WindowID(20))
    }

    /// The parity half of the one-ring guard
    /// (`AppWindowCycleSeamTests` holds the source half): the
    /// verb's `next` and Open or Focus's repeat press visit the
    /// same windows in the same order.
    @Test("next visits what focus_or_spawn's repeat press visits")
    func nextMatchesTheRepeatPress() {
        let verb = makeCore()
        let press = makeCore()
        let pressed: [WindowID?] = (0..<3).map { _ in
            #expect(
                press.execute(
                    "focus_or_spawn",
                    args: [.string(Self.bundle)]
                ).isSuccess
            )
            return press.state.workspaces.lastFocused
        }
        #expect(walk(verb, "next", times: 3) == pressed)
    }

    @Test("Another app in front is refused, focus unmoved")
    func otherFrontmostRefuses() {
        let core = makeCore()
        core.frontmostPIDProvider = { 999 }
        #expect(
            step(core, "next")
                == .fail("only the app in front cycles its windows")
        )
        #expect(core.state.workspaces.lastFocused == WindowID(20))
    }

    @Test("A lone window is refused")
    func loneWindowRefuses() {
        let core = makeCore()
        core.state.workspaces.focus(WindowID(30), in: "1")
        core.frontmostPIDProvider = { 300 }
        #expect(
            step(core, "next")
                == .fail("the focused app has no other window to focus")
        )
        #expect(core.state.workspaces.lastFocused == WindowID(30))
    }

    /// A focused transient overlay (#300) is outside its app's
    /// ring, refused as such rather than as a lone window.
    @Test("A focused transient overlay is refused as outside the ring")
    func focusedOverlayRefuses() {
        let core = makeCore()
        core.state.windows.upsert(
            ManagedWindow(
                id: WindowID(23),
                pid: 100,
                appName: "App100",
                appBundleID: Self.bundle,
                isTransientOverlay: true
            )
        )
        core.state.workspaces.add(WindowID(23), to: "1")
        core.state.workspaces.focus(WindowID(23), in: "1")
        #expect(
            step(core, "next")
                == .fail(
                    "a transient panel is not one of its app's windows"
                )
        )
        #expect(core.state.workspaces.lastFocused == WindowID(23))
    }

    @Test("A focused window with no bundle id is refused")
    func noBundleIDRefuses() {
        let core = makeCore()
        core.state.windows.upsert(
            ManagedWindow(id: WindowID(40), pid: 400, appName: "Bare")
        )
        core.state.workspaces.add(WindowID(40), to: "1")
        core.state.workspaces.focus(WindowID(40), in: "1")
        core.frontmostPIDProvider = { 400 }
        #expect(
            step(core, "next")
                == .fail("only an app with a bundle id cycles its windows")
        )
        #expect(core.state.workspaces.lastFocused == WindowID(40))
    }

    @Test("A direction outside prev|next is refused")
    func unknownDirectionRefuses() {
        let core = makeCore()
        #expect(
            step(core, "left")
                == .expected(ModeCycleDirection.self)
        )
        #expect(core.state.workspaces.lastFocused == WindowID(20))
    }
}
