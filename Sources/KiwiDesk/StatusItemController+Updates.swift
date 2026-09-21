import AppKit
import KiwiDeskCore

/// Quick menu update row and action (`AppUpdater`, #874).
extension StatusItemController {
    /// The row exists only while an update was FOUND — a scheduled
    /// one waiting behind the gentle reminder (#1013) or the
    /// channel's own answer (#1536) — and reads "Update Available…"
    /// (`LayoutMenuEnablementScanTests`). Asking for a check is the
    /// Settings footer's; the menu says something only when there
    /// is something to say. One row, one action: Sparkle brings the
    /// waiting alert forward on the same `checkForUpdates`.
    func makeUpdatesItem() -> NSMenuItem? {
        guard updatePending || updateFound else { return nil }
        let updates = NSMenuItem(
            title: L("menu.update_available", "Update Available…"),
            action: #selector(checkForUpdates(_:)),
            keyEquivalent: ""
        )
        updates.target = self
        updates.image = NSImage(
            systemSymbolName: "arrow.down.circle.fill",
            accessibilityDescription: nil
        )
        updates.isEnabled = updater.canCheckForUpdates
        return updates
    }

    private var updateFound: Bool {
        if case .available = updater.updates.state { return true }
        return false
    }

    /// Triggers software update check via Sparkle updater.
    @objc func checkForUpdates(_ sender: NSMenuItem) {
        guard updater.canCheckForUpdates else { return }
        NSApp.activate(ignoringOtherApps: true)
        updater.checkForUpdates()
    }
}
