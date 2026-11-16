import AppKit
import os

/// The panel's key-window lifecycle: the field takes the keys with
/// the panel, and losing key closes it.
extension JumpPanelController: NSWindowDelegate {
    /// The field takes the keys whenever the panel does.
    func windowDidBecomeKey(_ notification: Notification) {
        currentModel?.requestFieldFocus()
    }

    func windowDidResignKey(_ notification: Notification) {
        jumpLog.log("KiwiDesk: jump resign key; open \(self.isOpen)")
        close()
    }
}
