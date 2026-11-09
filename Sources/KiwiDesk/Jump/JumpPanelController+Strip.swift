import AppKit
import KiwiDeskCore

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

    func wireStrip(_ model: JumpModel, _ panel: JumpPanel) {
        // An empty field has no caret for ← → to move.
        panel.stripMoves = { [weak model] in
            model?.scope == .windows && model?.query.isEmpty == true
        }
        // An app the strip lists with no window reopens (#1840).
        model.onReopen = { [weak self] bundleID in
            guard self?.dismiss(distrusting: false) == true else { return }
            self?.core.reopenJumpApp(bundleID: bundleID)
        }
    }
}
