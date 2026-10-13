import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Issue #952's close half, after the panels went non-activating
/// (#1875): a close owes nothing — the window it keys again is the
/// one the user was in. `isAppActive` is forced rather than read
/// live (#565): a test process is never the real active app.
@Suite("Shortcuts panel close distrust (issue #952)")
@MainActor
struct ShortcutsPanelReturnTests {
    // MARK: - a close arms nothing

    /// The window a close keys again is the one the user was in,
    /// so its report is honored (owner ruling 2026-10-13).
    @Test("a close arms no distrust, even with KiwiDesk active")
    func closeArmsNothing() {
        let core = makeTestCore()
        let controller = ShortcutsPanelController(
            core: core,
            onEdit: {}
        )
        controller.handBack.isAppActive = { true }
        controller.close()
        #expect(core.ignoredPanel.active.isEmpty)
    }
}
