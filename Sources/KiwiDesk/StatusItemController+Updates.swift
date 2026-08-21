import AppKit
import KiwiDeskCore

/// The quick menu's "Check for Updates…" row (#874).
///
/// Its own file because both parents were one row from §2.1's
/// ceiling, and because the row and the action it fires are the
/// cohesive slice to lift — the seam they drive is
/// `AppUpdater.swift`, which owns the argument for why the
/// default is inert.
extension StatusItemController {
    /// Built here rather than inline in the menu builder, and
    /// added by it — so the row still has exactly one
    /// construction site, which is what
    /// `LayoutMenuEnablementScanTests` pairs against.
    ///
    /// Sits with Settings rather than beside Quit: both are
    /// app-level rather than workspace-level, and a menu-bar
    /// extra has no app menu for a Mac user to look in instead.
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
        // CONDITIONAL, so it states `isEnabled` rather than
        // inheriting it: the menu sets `autoenablesItems = false`,
        // under which an unstated row reads as enabled and a click
        // on it would go nowhere.
        //
        // Grey, never hide (gui.md): the capability exists and is
        // momentarily unavailable — Sparkle refuses while a check
        // is already running or an update is mid-install — and
        // hiding it would teach the user it does not exist.
        updates.isEnabled = updater.canCheckForUpdates
        return updates
    }

    /// Hand the check to Sparkle, which owns every piece of UI
    /// from here — including the "you're up to date" answer, which
    /// is why this reports nothing itself.
    ///
    /// Re-reads `canCheckForUpdates` rather than trusting the row:
    /// the menu is built on open and can be up while a scheduled
    /// check starts underneath it, so the state the row was built
    /// from is not necessarily the state at click.
    @objc func checkForUpdates(_ sender: NSMenuItem) {
        guard updater.canCheckForUpdates else { return }
        updater.checkForUpdates()
    }
}
