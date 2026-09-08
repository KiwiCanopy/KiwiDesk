import AppKit
import KiwiDeskCore

/// Quick menu check for updates item and action (`AppUpdater`, #874).
extension StatusItemController {
    /// Builds updates menu item (`LayoutMenuEnablementScanTests`).
    /// While a scheduled update waits behind the gentle reminder
    /// the SAME row reads "Update Available…" (#1013): one row,
    /// one action — Sparkle brings the waiting alert forward on
    /// the same `checkForUpdates` a fresh check takes.
    func makeUpdatesItem() -> NSMenuItem {
        let updates = NSMenuItem(
            title: updatePending
                ? L("menu.update_available", "Update Available…")
                : L("menu.check_updates", "Check for Updates…"),
            action: #selector(checkForUpdates(_:)),
            keyEquivalent: ""
        )
        updates.target = self
        updates.image = NSImage(
            systemSymbolName: updatePending
                ? "arrow.down.circle.fill" : "arrow.down.circle",
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
