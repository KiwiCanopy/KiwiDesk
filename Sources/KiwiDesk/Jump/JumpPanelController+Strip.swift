import AppKit
import KiwiDeskCore
import os

/// The Windows side's app strip (#3135): its opener, which puts the
/// strip on the app of the window used last, and its wiring.
extension JumpPanelController {
    /// `kiwihub.show_last_app()`: as the Windows side's own
    /// shortcut — it closes the panel where Windows is up — but the
    /// strip lands on the last app wherever it opens or switches.
    func toggleLastApp() {
        switch Self.toggleAction(
            showing: isOpen ? currentModel?.scope : nil,
            asked: .windows
        ) {
        case .open: show(.windows, lastApp: true)
        case .close: close()
        case .switchScope:
            currentModel?.setScope(.windows)
            currentModel?.openOnLastApp()
        }
    }

    func wireStrip(_ model: JumpModel) {
        // An app the strip lists with no window reopens (#1840).
        model.onReopen = { [weak self] app in
            self?.reopen(app)
        }
    }

    /// Closes on the pick, as a row's does, then reopens the app.
    private func reopen(_ app: JumpApp) {
        guard let bundleID = app.bundleID,
            dismiss(
                distrusting: Self.distrustsHandoff(
                    pick: app.pid,
                    own: ProcessInfo.processInfo.processIdentifier
                )
            )
        else { return }
        jumpLog.log("KiwiDesk: jump pick reopen")
        core.reopenJumpApp(bundleID: bundleID)
    }
}
