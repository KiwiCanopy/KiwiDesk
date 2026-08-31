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
        updates.isEnabled = updater.canCheckForUpdates
        return updates
    }

    /// Triggers software update check via Sparkle updater.
    @objc func checkForUpdates(_ sender: NSMenuItem) {
        guard updater.canCheckForUpdates else { return }
        NSApp.activate(ignoringOtherApps: true)
        updater.checkForUpdates()
    }
}
