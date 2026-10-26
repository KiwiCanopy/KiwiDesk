import KiwiDeskCore

/// Search enrichment for SettingsModel (#678).
extension SettingsModel {
    /// Staged value for a census key, as the diff rows narrate
    /// it — `SettingsValueReadout` with the draft on BOTH sides,
    /// so the "new" column IS the current value and search
    /// cannot name a value two ways.
    func searchValue(for key: SettingKey) -> String? {
        SettingsValueReadout.rows(
            for: key,
            old: config,
            new: config
        )
        .first?
        .newValue
    }

}
