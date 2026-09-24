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

    /// "What's New in X…" while a login launch left it waiting
    /// (#1542), in the updates row's shape: it exists only then.
    func makeWhatsNewItem() -> NSMenuItem? {
        guard let version = whatsNewWaiting else { return nil }
        let item = NSMenuItem(
            title: L(
                "menu.whats_new",
                "What's New in KiwiDesk %1$@…",
                version
            ),
            action: #selector(showWhatsNew(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.image = NSImage(
            systemSymbolName: "sparkles",
            accessibilityDescription: nil
        )
        item.isEnabled = true
        return item
    }

    @objc func showWhatsNew(_ sender: NSMenuItem) {
        whatsNew?.show()
    }
}
