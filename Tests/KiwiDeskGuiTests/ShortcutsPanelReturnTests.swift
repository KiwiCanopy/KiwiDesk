import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Issue #952: `show()` steals activation
/// (`NSApp.activate(ignoringOtherApps: true)`) so the borderless
/// panel can receive Esc, but `close()` only `orderOut`ed — so
/// when Settings was open, macOS keyed IT next instead of
/// returning focus to whatever was frontmost before the summon.
/// The fix remembers that app (`returnTarget`) and hands
/// activation back on a keyboard-commanded close.
///
/// Never calls `show()` (activates the app, builds real panels);
/// state is set directly on the controller, and the two machine
/// reads are replaced with test doubles (#565 pattern):
/// `activateReturnTarget` records instead of activating, and
/// `isAppActive` is forced rather than read live — a test
/// process is never the real active app, so leaving it live
/// would make the yield gate impossible to exercise true.
@Suite("Shortcuts panel return-activation (issue #952)")
@MainActor
struct ShortcutsPanelReturnTests {
    private func makeController() -> ShortcutsPanelController {
        let core = makeTestCore()
        return ShortcutsPanelController(core: core, onEdit: {})
    }

    // MARK: - The pure decision, all arms

    @Test("Yields only when commanded, active, with a target")
    func yieldsWhenAllThreeHold() {
        #expect(
            ShortcutsPanelController.shouldYield(
                commanded: true,
                appActive: true,
                target: NSRunningApplication.current
            )
        )
    }

    @Test("Does not yield an uncommanded (click-away) close")
    func doesNotYieldUncommanded() {
        #expect(
            !ShortcutsPanelController.shouldYield(
                commanded: false,
                appActive: true,
                target: NSRunningApplication.current
            )
        )
    }

    @Test("Does not yield while KiwiDesk is not the active app")
    func doesNotYieldWhenInactive() {
        #expect(
            !ShortcutsPanelController.shouldYield(
                commanded: true,
                appActive: false,
                target: NSRunningApplication.current
            )
        )
    }

    @Test("Does not yield with no remembered target")
    func doesNotYieldWithNoTarget() {
        #expect(
            !ShortcutsPanelController.shouldYield(
                commanded: true,
                appActive: true,
                target: nil
            )
        )
    }

    // MARK: - Wiring: close(yieldingActivation:) consults it

    @Test(
        """
        A keyboard-commanded close (Escape's yieldingActivation: \
        true), active and with a remembered target, fires the \
        seam with that target — reds if close stops yielding
        """
    )
    func closeYieldsUnderInjectedConditions() {
        let controller = makeController()
        let target = NSRunningApplication.current
        controller.returnTarget = target
        controller.isAppActive = { true }
        var recorded: NSRunningApplication?
        controller.activateReturnTarget = { recorded = $0 }
        controller.close(yieldingActivation: true)
        #expect(recorded === target)
    }

    @Test(
        "An inactive app close does not fire the seam"
    )
    func closeDoesNotYieldWhenInactive() {
        let controller = makeController()
        controller.returnTarget = NSRunningApplication.current
        controller.isAppActive = { false }
        var recorded: NSRunningApplication?
        controller.activateReturnTarget = { recorded = $0 }
        controller.close(yieldingActivation: true)
        #expect(recorded == nil)
    }

    // MARK: - windowDidResignKey's click-away never yields

    @Test(
        """
        A resign-key close never fires the seam, even while \
        active with a target
        """
    )
    func resignKeyNeverYields() {
        let controller = makeController()
        controller.returnTarget = NSRunningApplication.current
        controller.isAppActive = { true }
        var recorded: NSRunningApplication?
        controller.activateReturnTarget = { recorded = $0 }
        controller.close(yieldingActivation: false)
        #expect(recorded == nil)
    }

    // MARK: - close arms the own-pid dismiss distrust

    @Test(
        """
        A commanded close of the still-active app arms the \
        dismiss distrust for our own pid (#952): its orderOut \
        blip-keys Settings, and AX's clickless re-report lands \
        after the activation yield — the grace must consume it
        """
    )
    func commandedActiveCloseArmsOwnDismissDistrust() {
        let core = makeTestCore()
        let controller = ShortcutsPanelController(
            core: core,
            onEdit: {}
        )
        controller.isAppActive = { true }
        controller.close(yieldingActivation: true)
        #expect(
            core.ignoredPanel.active.contains(
                pid_t(ProcessInfo.processInfo.processIdentifier)
            )
        )
    }

    @Test(
        """
        An uncommanded close never arms it — the click-away and \
        Edit-in-Settings closes are followed by focus the user \
        INTENDS, and arming there ate it (review, 2026-08-23)
        """
    )
    func uncommandedCloseNeverArms() {
        let core = makeTestCore()
        let controller = ShortcutsPanelController(
            core: core,
            onEdit: {}
        )
        controller.isAppActive = { true }
        controller.close(yieldingActivation: false)
        #expect(core.ignoredPanel.active.isEmpty)
    }

    // MARK: - A double close cannot yield twice

    @Test(
        "A second close after a yielding one fires nothing more"
    )
    func doubleCloseConsumesTarget() {
        let controller = makeController()
        controller.returnTarget = NSRunningApplication.current
        controller.isAppActive = { true }
        var callCount = 0
        controller.activateReturnTarget = { _ in callCount += 1 }
        controller.close(yieldingActivation: true)
        #expect(callCount == 1)
        controller.close(yieldingActivation: true)
        #expect(callCount == 1)
        #expect(controller.returnTarget == nil)
    }
}
