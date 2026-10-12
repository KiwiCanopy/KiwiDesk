import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Issue #952's close half, after the panels went non-activating
/// (#1875): there is no activation to hand back, and what a close
/// still owes is the dismiss distrust for our own pid — armed on a
/// commanded close of the still-active app, never on a click away.
/// `isAppActive` is forced rather than read live (#565): a test
/// process is never the real active app.
@Suite("Shortcuts panel close distrust (issue #952)")
@MainActor
struct ShortcutsPanelReturnTests {
    // MARK: - close arms the own-pid dismiss distrust

    @Test(
        """
        A commanded close of the still-active app arms the \
        dismiss distrust for our own pid (#952): its orderOut \
        blip-keys Settings, and AX's clickless re-report must be \
        consumed by the grace
        """
    )
    func commandedActiveCloseArmsOwnDismissDistrust() {
        let core = makeTestCore()
        let controller = ShortcutsPanelController(
            core: core,
            onEdit: {}
        )
        controller.handBack.isAppActive = { true }
        controller.close(commanded: true)
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
        controller.handBack.isAppActive = { true }
        controller.close(commanded: false)
        #expect(core.ignoredPanel.active.isEmpty)
    }
}
