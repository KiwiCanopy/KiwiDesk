import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Issue #244: dismissing an ignored panel (Ghostty's quick
/// terminal) makes AX re-report the app's managed main window
/// as focused. That window can live on another space, and the
/// stale report must not follow focus there — nor, same-space,
/// yank focus to the main window in a focus-driven layout. The
/// panel is flagged active while it holds focus (#21); the flag
/// is consumed by the dismiss report and the pre-panel focus is
/// restored instead.
@Suite("Ignored-panel dismiss focus (issue #244)", .serialized)
@MainActor
struct IgnoredPanelDismissTests {
    private func makeCore() -> KiwiCore {
        KiwiCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-panel-\(UUID().uuidString)"
                )
        )
    }

    private func addWindow(
        _ core: KiwiCore,
        _ raw: UInt32,
        pid: pid_t
    ) {
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(raw),
                    pid: pid,
                    appName: "App\(raw)"
                )
            )
        )
    }

    /// The app's main window (id 2, pid 2) on space 2, with a
    /// normal window (id 1, pid 1) holding focus on the active
    /// space 1. Mirrors the state at panel-dismiss time.
    private func twoSpaceSetup() -> KiwiCore {
        let core = makeCore()
        addWindow(core, 1, pid: 1)
        addWindow(core, 2, pid: 2)
        // Move the main window to space 2 (no follow); focus
        // falls back to window 1 on the active space 1.
        _ = core.execute("move_to_space", args: [.string("2")])
        core.deferred.cancel(.focusFollow)
        return core
    }

    @Test("onIgnoredPanelFocus flags the app's pid")
    func signalSetsFlag() {
        let core = makeCore()
        #expect(core.ignoredPanelActive.isEmpty)
        // The event loop fires this when it filters an ignored
        // panel's own focus report (#21); the wiring must flag
        // the pid so the dismiss transition can be caught.
        core.eventLoop.onIgnoredPanelFocus(7)
        #expect(core.ignoredPanelActive.contains(7))
    }

    @Test(
        """
        A dismiss report for a main window on another space is \
        suppressed — no follow, focus kept
        """
    )
    func dismissDoesNotFollowCrossSpace() {
        let core = twoSpaceSetup()
        core.ignoredPanelActive.insert(2)
        core.handle(.windowFocused(WindowID(2)))
        #expect(core.deferred.task(for: .focusFollow) == nil)
        #expect(
            core.state.workspaces.activeSpace == SpaceID(1)
        )
        #expect(core.ignoredPanelActive.isEmpty)
        #expect(
            core.state.workspaces[SpaceID(1)]?.focused
                == WindowID(1)
        )
    }

    @Test(
        """
        Without the panel flag the same report follows focus \
        cross-space (guards the setup)
        """
    )
    func withoutFlagFollowsCrossSpace() {
        let core = twoSpaceSetup()
        core.handle(.windowFocused(WindowID(2)))
        #expect(core.deferred.task(for: .focusFollow) != nil)
    }

    @Test(
        """
        Same-space dismiss keeps focus on the pre-panel window, \
        not the main window (focus-driven layout)
        """
    )
    func dismissKeepsFocusSameSpace() {
        let core = makeCore()
        addWindow(core, 1, pid: 1)
        addWindow(core, 2, pid: 2)
        core.state.workspaces.setMode(SpaceID(1), .scrolling)
        // The user was on window 1 before opening the panel;
        // window 2 is the app's managed main window.
        core.state.workspaces.focus(WindowID(1), in: SpaceID(1))
        core.ignoredPanelActive.insert(2)
        core.handle(.windowFocused(WindowID(2)))
        #expect(
            core.state.workspaces[SpaceID(1)]?.focused
                == WindowID(1)
        )
        #expect(core.ignoredPanelActive.isEmpty)
    }
}
