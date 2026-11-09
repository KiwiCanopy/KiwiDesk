import AppKit
import KiwiDeskCore
import os

/// The Windows side's app strip (#3135): its opener, which puts the
/// strip on the app of the window used last, and its wiring.
extension JumpPanelController {
    /// `kiwihub.show_last_app()`: opens Windows with the strip on
    /// the last app, or switches there from another side; pressed
    /// again while Windows is up, it steps to the next app, as ⌘⇥
    /// does (#3135, owner 2026-11-09). Esc closes.
    func toggleLastApp() {
        switch Self.lastAppAction(
            showing: isOpen ? currentModel?.scope : nil
        ) {
        case .open: show(.windows, lastApp: true)
        case .step: currentModel?.handle(.side(1), repeated: false)
        case .switchScope:
            currentModel?.setScope(.windows)
            currentModel?.openOnLastApp()
        }
    }

    enum LastAppAction: Equatable { case open, step, switchScope }

    /// Steps where Windows already shows, switches where another
    /// side does, else opens.
    static func lastAppAction(showing: JumpScope?) -> LastAppAction {
        guard let showing else { return .open }
        return showing == .windows ? .step : .switchScope
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
