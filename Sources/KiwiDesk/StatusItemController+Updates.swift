import AppKit
import KiwiDeskCore

/// Quick menu check for updates item and action (`AppUpdater`, #874).
extension StatusItemController {
    /// Builds updates menu item (`LayoutMenuEnablementScanTests`).
    func makeUpdatesItem() -> NSMenuItem {
        let updates = NSMenuItem(
            title: L("menu.check_updates", "Check for Updates…"),
            action: #selector(checkForUpdates(_:)),
            keyEquivalent: ""
        )
        updates.target = self
        updates.image = NSImage(
            systemSymbolName: "arrow.down.circle",
            accessibilityDescription: nil
        )
        // The first quick-menu row whose enablement is
        // CONDITIONAL, so it states `isEnabled` (the menu turned
        // auto-enable off). Grey, never hide (gui.md): Sparkle
        // refuses while a check runs, and hiding the row would
        // teach the user the capability does not exist.
        updates.isEnabled = updater.canCheckForUpdates
        return updates
    }

    /// Hands the check to Sparkle, which owns every piece of UI
    /// from here. Re-reads `canCheckForUpdates` rather than
    /// trusting the row: the menu can be up while a scheduled
    /// check starts underneath it.
    @objc func checkForUpdates(_ sender: NSMenuItem) {
        guard updater.canCheckForUpdates else { return }
        NSApp.activate(ignoringOtherApps: true)
        updater.checkForUpdates()
    }
}
