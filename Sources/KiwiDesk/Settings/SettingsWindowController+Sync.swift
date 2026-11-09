import KiwiDeskCore

/// Sync across Macs reaching an open Settings (#2324, #3088).
extension SettingsWindowController {
    /// A change the sync folder brought in, and where following
    /// stands (#2324 slice 3).
    func adoptSyncedChange(_ change: SyncedChange) {
        model.adoptSyncedChange(change)
    }

    func syncStatusChanged(_ status: SyncStatus) {
        model.sync.status = status
    }

    /// Shows Settings on the Sync across Macs row (#3088).
    func showSyncAcrossMacs() {
        model.land(on: .syncAcrossMacs)
        show()
    }
}
