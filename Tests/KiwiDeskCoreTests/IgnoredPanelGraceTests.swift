import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Issue #951: a genuine click on another window cleared
/// `ignoredPanel.active` synchronously, but a dismissed panel
/// app's stale main-window re-report could land 125-200 ms
/// later and be honored — the flag must survive a short
/// dismissal grace instead. `IgnoredPanelDismissTests` (#244)
/// covers the original same-pid consume path; this suite covers
/// the grace state machine `shouldConsumeIgnoredPanelReport`
/// added for #951.
@Suite("Ignored-panel dismiss grace (issue #951)", .serialized)
@MainActor
struct IgnoredPanelGraceTests {
    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-panel-grace-\(UUID().uuidString)"
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

    @Test(
        """
        A same-app-resigned other-app focus does not clear the \
        flag: the panel app's dismiss re-report is still \
        consumed after it (the #951 race regression)
        """
    )
    func raceRegressionStillConsumesReport() {
        let core = makeCore()
        // A (pid 1) and B (pid 2) are ordinary tracked windows;
        // W (pid 3, the panel app's managed main window) is the
        // stale re-report's target.
        addWindow(core, 1, pid: 1)
        addWindow(core, 2, pid: 2)
        addWindow(core, 3, pid: 3)
        core.state.workspaces.focus(WindowID(1), in: SpaceID(1))
        core.armIgnoredPanel(3)
        // The click on B: this used to clear the flag
        // synchronously via `ignoredPanel.active.removeAll()`.
        core.handle(.windowFocused(WindowID(2)))
        #expect(
            core.state.workspaces[SpaceID(1)]?.focused
                == WindowID(2)
        )
        #expect(core.ignoredPanel.active.contains(3))
        // The panel app's stale re-report, landing after the
        // click — must still be consumed, not honored.
        core.handle(.windowFocused(WindowID(3)))
        #expect(
            core.state.workspaces[SpaceID(1)]?.focused
                == WindowID(2)
        )
    }

    @Test(
        """
        A report with click provenance escapes distrust and \
        clears the flags, even while flagged
        """
    )
    func clickProvenanceEscapes() {
        let core = makeCore()
        addWindow(core, 1, pid: 1)
        addWindow(core, 2, pid: 2)
        addWindow(core, 3, pid: 3)
        core.state.workspaces.focus(WindowID(1), in: SpaceID(1))
        core.armIgnoredPanel(3)
        core.handle(.windowFocused(WindowID(2)))
        // A fresh click that actually reached W (#687
        // provenance) — genuine focus, not a stale re-report.
        core.lastLeftClick = (
            at: Date(), point: .zero, reached: WindowID(3)
        )
        core.handle(.windowFocused(WindowID(3)))
        #expect(
            core.state.workspaces[SpaceID(1)]?.focused
                == WindowID(3)
        )
        #expect(core.ignoredPanel.active.isEmpty)
        #expect(core.ignoredPanel.dismissDeadline == nil)
    }

    @Test(
        """
        A deadline already in the past clears the flags on the \
        next other-app report, and a later panel-app report is \
        then honored
        """
    )
    func graceExpiryClearsFlags() {
        let core = makeCore()
        addWindow(core, 1, pid: 1)
        addWindow(core, 2, pid: 9)
        core.state.workspaces.focus(WindowID(2), in: SpaceID(1))
        core.armIgnoredPanel(9)
        core.ignoredPanel.dismissDeadline = Date(
            timeIntervalSinceNow: -1
        )
        core.handle(.windowFocused(WindowID(1)))
        #expect(core.ignoredPanel.active.isEmpty)
        #expect(core.ignoredPanel.dismissDeadline == nil)
        #expect(
            core.state.workspaces[SpaceID(1)]?.focused
                == WindowID(1)
        )
        // Flags are gone, so this later pid-9 report is
        // ordinary genuine focus and is honored.
        core.handle(.windowFocused(WindowID(2)))
        #expect(
            core.state.workspaces[SpaceID(1)]?.focused
                == WindowID(2)
        )
    }

    @Test(
        """
        A FLAGGED app's report after the grace expired is \
        honored, not consumed — the past deadline clears the \
        flags whatever pid reports (review, 2026-08-23): \
        without the transition, a genuine clickless focus of \
        the panel app minutes later was still eaten
        """
    )
    func expiredGraceHonorsFlaggedAppReport() {
        let core = makeCore()
        addWindow(core, 1, pid: 1)
        addWindow(core, 2, pid: 9)
        core.state.workspaces.focus(WindowID(1), in: SpaceID(1))
        core.armIgnoredPanel(9)
        core.ignoredPanel.dismissDeadline = Date(
            timeIntervalSinceNow: -1
        )
        core.handle(.windowFocused(WindowID(2)))
        #expect(core.ignoredPanel.active.isEmpty)
        #expect(core.ignoredPanel.dismissDeadline == nil)
        #expect(
            core.state.workspaces[SpaceID(1)]?.focused
                == WindowID(2)
        )
    }

    @Test("armIgnoredPanel resets an existing dismiss deadline")
    func armResetsDeadline() {
        let core = makeCore()
        core.ignoredPanel.dismissDeadline = Date()
        core.armIgnoredPanel(5)
        #expect(core.ignoredPanel.active.contains(5))
        #expect(core.ignoredPanel.dismissDeadline == nil)
    }

    /// The consume keeps the window's self-raise stamp (#887):
    /// age bounds it, and the #465 order read needs it as the
    /// newer sibling — a consume that dropped it let the panel
    /// app's next hidden-sibling re-report through to the follow.
    @Test("The consume keeps the self-raise stamp for the order read")
    func consumeKeepsSelfRaiseStamp() {
        let core = makeCore()
        addWindow(core, 1, pid: 1)
        addWindow(core, 3, pid: 3)
        addWindow(core, 4, pid: 3)
        core.moveWindow(WindowID(4), to: SpaceID(2), follow: false)
        core.moveLatch.stamp(
            WindowID(4),
            at: Date(
                timeIntervalSinceNow: -MoveIntentLatch.window - 1
            )
        )
        core.state.workspaces.focus(WindowID(1), in: SpaceID(1))
        // KiwiDesk raised the panel app's main window, then the
        // quick terminal took and dropped focus.
        core.selfRaiseStamps[WindowID(3)] = Date()
        core.armIgnoredPanel(3)
        core.handle(.windowFocused(WindowID(3)))
        #expect(core.selfRaiseStamps[WindowID(3)] != nil)
        // The app's stale re-report of its hidden sibling is
        // still distrusted by that stamp — no follow.
        core.handle(.windowFocused(WindowID(4)))
        #expect(core.deferred.task(for: .focusFollow) == nil)
        #expect(
            core.state.workspaces.activeSpace == SpaceID(1)
        )
    }
}
