import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The wake/unlock focus payment and its #292 heal (#1130): the
/// replay must pay the adopted focus for real, and a denial while
/// the payment is unconfirmed re-seeds from the OS frontmost once
/// instead of dying on every press until a click.
@Suite("Wake focus payment (#1130)", .serialized)
@MainActor
struct WakeFocusRestoreTests {
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-wake-focus-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1600, height: 1000)
        }
        return core
    }

    private func addWindow(
        _ core: KiwiCore,
        _ raw: UInt32,
        pid: pid_t = 1
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

    /// A real self observer so `observes(pid)` is true — the
    /// `FocusedCommandGuardTests` idiom.
    private func observe(_ core: KiwiCore, pid: pid_t) {
        guard let observer = AXApplicationObserver(pid: pid)
        else {
            Issue.record("could not create a self AX observer")
            return
        }
        core.eventLoop.observers[pid] = observer
    }

    @Test(
        """
        The wake leg re-focuses the snapshot's window over a \
        fresher OS focus, and arms the one-shot heal
        """
    )
    func wakeLegPaysTheRememberedFocus() {
        let core = makeCore()
        addWindow(core, 1)
        addWindow(core, 2)
        guard let space = core.state.workspaces.activeSpace
        else {
            Issue.record("no active space")
            return
        }
        core.state.workspaces.focus(WindowID(1), in: space)
        let snapshot = core.state.snapshot()
        // macOS restores its own key app after unlock (#1130's
        // log: Claude honored one second before the replay).
        core.state.workspaces.focus(WindowID(2), in: space)
        core.sleepWake.restoreState(snapshot)
        #expect(core.focusedWindowID == WindowID(1))
        #expect(core.wakeFocusHealArmed)
    }

    @Test("The crash leg stays a bare replay: no heal armed")
    func crashLegDoesNotArm() {
        let core = makeCore()
        addWindow(core, 1)
        let snapshot = core.state.snapshot()
        core.crash.restoreState(snapshot)
        #expect(!core.wakeFocusHealArmed)
    }

    @Test(
        """
        A remembered focus that is gone falls back to seeding \
        from the OS frontmost instead of a dead stamp
        """
    )
    func goneFocusSeedsFromFrontmost() {
        let core = makeCore()
        addWindow(core, 1)
        guard let space = core.state.workspaces.activeSpace
        else {
            Issue.record("no active space")
            return
        }
        core.state.workspaces.focus(WindowID(1), in: space)
        let snapshot = core.state.snapshot()
        core.state.apply(
            .windowDestroyed(WindowID(1), wasMinimized: false)
        )
        addWindow(core, 2)
        // Clear the spawn grant so only the payment's seed can
        // put the focus back.
        core.state.workspaces.withSpace(space) {
            $0.focused = nil
        }
        core.trustedFrontmostProvider = { WindowID(2) }
        core.restoreAndSettleAfterWake(snapshot)
        #expect(core.focusedWindowID == WindowID(2))
    }

    @Test(
        """
        An armed heal re-seeds from the frontmost and allows \
        the press the stale anchor would have denied
        """
    )
    func armedHealAllowsThePress() {
        let core = makeCore()
        let own = getpid()
        addWindow(core, 2, pid: own)
        addWindow(core, 1, pid: 1)
        guard let space = core.state.workspaces.activeSpace
        else {
            Issue.record("no active space")
            return
        }
        // The stale wake anchor: w1, while the OS front is w2.
        core.state.workspaces.focus(WindowID(1), in: space)
        observe(core, pid: own)
        core.frontmostPIDProvider = { own }
        core.trustedFrontmostProvider = { WindowID(2) }
        core.wakeFocusHealArmed = true
        let response = core.execute("make_floating")
        #expect(response.isSuccess)
        #expect(core.focusedWindowID == WindowID(2))
        #expect(!core.wakeFocusHealArmed)
    }

    @Test("Unarmed, the same divergence still fails closed")
    func unarmedDenialStands() {
        let core = makeCore()
        let own = getpid()
        addWindow(core, 2, pid: own)
        addWindow(core, 1, pid: 1)
        guard let space = core.state.workspaces.activeSpace
        else {
            Issue.record("no active space")
            return
        }
        core.state.workspaces.focus(WindowID(1), in: space)
        observe(core, pid: own)
        core.frontmostPIDProvider = { own }
        core.trustedFrontmostProvider = { WindowID(2) }
        let response = core.execute("make_floating")
        #expect(!response.isSuccess)
        #expect(core.focusedWindowID == WindowID(1))
    }

    @Test(
        """
        The heal is one-shot: a reseed that cannot own the \
        foreground consumes the arm and fails closed
        """
    )
    func healConsumesEvenWhenItCannotFix() {
        let core = makeCore()
        addWindow(core, 1, pid: 1)
        core.frontmostPIDProvider = { 999 }
        core.trustedFrontmostProvider = { nil }
        core.wakeFocusHealArmed = true
        let response = core.execute("make_floating")
        #expect(!response.isSuccess)
        #expect(!core.wakeFocusHealArmed)
    }

    @Test("An honored focus event disarms the heal")
    func honoredFocusDisarms() {
        let core = makeCore()
        addWindow(core, 1)
        addWindow(core, 2)
        core.wakeFocusHealArmed = true
        core.handle(.windowFocused(WindowID(1)))
        #expect(!core.wakeFocusHealArmed)
    }
}
