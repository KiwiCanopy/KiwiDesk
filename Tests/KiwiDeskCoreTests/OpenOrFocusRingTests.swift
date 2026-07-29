import Foundation
import Testing

@testable import KiwiDeskCore

/// #636: Open or Focus (`pull_or_spawn`) pulls a window forward
/// on another space; the focused ring must land on it after the
/// switch. The shortcut itself is a fire-and-forget
/// `NSRunningApplication.activate()`, so everything KiwiDesk
/// knows arrives as racing events afterwards — these suites
/// replay the two orderings that switch spaces.
@MainActor
@Suite("Open-or-focus ring after space switch", .serialized)
struct OpenOrFocusRingTests {

    private func makeCore() -> KiwiCore {
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 875)
        }
        return core
    }

    private func window(
        _ id: UInt32,
        pid: pid_t
    ) -> ManagedWindow {
        ManagedWindow(
            id: WindowID(id),
            pid: pid,
            appName: "App\(pid)",
            appBundleID: "app.test.\(pid)"
        )
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

    // MARK: - Virtual-space follow path

    /// Space 1 active; the aimed window (20) and another app's
    /// window (30) live on space 2, whose last-focused was 30.
    /// The activation's focus report lands, the focus-follow
    /// switches — the ring must sit on 20, in focused colour.
    @Test("Follow switch rings the reported window")
    func followSwitchRingsAimedWindow() {
        let core = makeCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.ensureSpace("2")
        core.state.workspaces.activate("1")
        let pids: [(UInt32, pid_t)] = [
            (10, 200), (20, 100), (30, 300),
        ]
        for (id, pid) in pids {
            core.state.windows.upsert(window(id, pid: pid))
        }
        core.state.workspaces.add(WindowID(10), to: "1")
        core.state.workspaces.add(WindowID(20), to: "2")
        core.state.workspaces.add(WindowID(30), to: "2")
        core.state.workspaces.focus(WindowID(30), in: "2")
        core.state.workspaces.focus(WindowID(10), in: "1")

        // The activation report for the hidden aimed window.
        core.handle(.windowFocused(WindowID(20)))
        #expect(core.deferred.task(for: .focusFollow) != nil)
        // The follow body's switch (its NSWorkspace guards are
        // uncheckable here; the switch is what it commits).
        core.applyFocusedSpaceSwitch(to: "2")

        let focused = core.tiler.settings.borderStyle.focusedColor
        #expect(ring(core, 20)?.colorHex == focused)
        #expect(ring(core, 30) == nil)
    }

    // MARK: - Native-switch re-track path

    /// Both windows of desktop 2 vanish when the user leaves and
    /// are re-tracked when the shortcut pulls them back. The
    /// activation notification lands first (re-tracks the aimed
    /// window, reports its focus), THEN the space-change
    /// reconcile re-tracks the other window — whose create-fold
    /// must not steal the focus the OS just reported (#636).
    @Test("Re-track after the focus report keeps the ring")
    func reTrackDoesNotStealReportedFocus() {
        let core = makeCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")

        // On desktop 2: aimed (20) and another app (30); the
        // other window was focused last.
        core.handle(.windowCreated(window(20, pid: 100)))
        core.handle(.windowCreated(window(30, pid: 300)))
        core.handle(.windowFocused(WindowID(30)))

        // Leave for desktop 1: both vanish, its window appears.
        core.handle(.nativeSpaceChanged)
        core.handle(
            .windowDestroyed(WindowID(20), wasMinimized: false)
        )
        core.handle(
            .windowDestroyed(WindowID(30), wasMinimized: false)
        )
        core.handle(.windowCreated(window(10, pid: 200)))
        core.handle(.windowFocused(WindowID(10)))

        // Shortcut: macOS switches back. Activation notification
        // first — the aimed window is re-tracked and reported
        // focused — then the bulk reconcile re-tracks the rest.
        core.handle(.nativeSpaceChanged)
        core.handle(.windowCreated(window(20, pid: 100)))
        core.handle(.windowFocused(WindowID(20)))
        core.handle(.windowCreated(window(30, pid: 300)))
        core.handle(
            .windowDestroyed(WindowID(10), wasMinimized: false)
        )

        #expect(
            core.state.workspaces.lastFocused == WindowID(20)
        )
        let focused = core.tiler.settings.borderStyle.focusedColor
        #expect(ring(core, 20)?.colorHex == focused)
        #expect(ring(core, 30) == nil)
    }

    /// Scope guard for the fix: a genuinely NEW window (no
    /// remembered space) still takes its space's focus — spawn
    /// focus is untouched.
    @Test("A fresh spawn still takes focus")
    func freshSpawnStillTakesFocus() {
        let core = makeCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        core.handle(.windowCreated(window(10, pid: 200)))
        core.handle(.windowFocused(WindowID(10)))
        core.handle(.windowCreated(window(11, pid: 200)))
        #expect(
            core.state.workspaces.lastFocused == WindowID(11)
        )
    }
}
