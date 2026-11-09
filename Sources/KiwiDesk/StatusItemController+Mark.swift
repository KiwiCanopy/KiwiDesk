import AppKit
import KiwiDeskCore

/// The orange mark's pending facts and the Sync Paused… row
/// (#1013, #1542, #3088; `docs/design-decisions.md`).
extension StatusItemController {
    /// The mark, on both channels and in ONE place (#1013).
    func applyMark(to button: NSStatusBarButton) {
        guard let mark = markNarration else { return }
        if let image = button.image {
            button.image = Self.badged(image)
        }
        button.setAccessibilityLabel(mark.label)
        button.toolTip = mark.tooltip
    }

    /// What the mark says, by rank: an update waiting, then a
    /// stopped sync, then the notes of one already installed
    /// (#1013, #3088, #1542).
    var markNarration: (label: String, tooltip: String)? {
        if updatePending {
            return (
                L("menu.status.update.a11y", "KiwiDesk (update available)"),
                L(
                    "menu.status.update.tooltip",
                    "A KiwiDesk update is available — open the menu to "
                        + "install it."
                )
            )
        }
        if syncStopped {
            return (
                L("menu.status.sync_paused.a11y", "KiwiDesk (sync paused)"),
                L(
                    "menu.status.sync_paused.tooltip",
                    "%1$@ is paused — open the menu to see why.",
                    L("general.sync", "Sync across Macs")
                )
            )
        }
        guard let version = whatsNewWaiting else { return nil }
        return (
            L(
                "menu.status.whats_new.a11y",
                "KiwiDesk (what's new in %1$@)",
                version
            ),
            L(
                "menu.status.whats_new.tooltip",
                "KiwiDesk was updated — open the menu to see what's new."
            )
        )
    }

    /// Whether `status` stops every pass until the user acts
    /// (#3088). A conflict copy and an unreachable folder keep
    /// syncing or wait; `.newerHere` is already a Config Issue.
    static func stopsSync(_ status: SyncStatus) -> Bool {
        switch status {
        case .newerOnAnotherMac, .changedOnBoth:
            return true
        case .off, .upToDate, .folderUnavailable, .conflictCopy,
            .newerHere:
            return false
        }
    }

    /// "Sync Paused…" while following has stopped (#3088), in the
    /// updates row's shape: it exists only then, and shows beside
    /// Update Available… when both hold (#3088 ruling).
    func makeSyncPausedItem() -> NSMenuItem? {
        guard syncStopped else { return nil }
        let item = NSMenuItem(
            title: L("menu.sync_paused", "Sync Paused…"),
            action: #selector(showSyncStatus(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.image = NSImage(
            systemSymbolName: "exclamationmark.arrow.triangle.2.circlepath",
            accessibilityDescription: nil
        )
        item.isEnabled = true
        return item
    }

    @objc func showSyncStatus(_ sender: NSMenuItem) {
        onShowSyncStatus()
    }
}
