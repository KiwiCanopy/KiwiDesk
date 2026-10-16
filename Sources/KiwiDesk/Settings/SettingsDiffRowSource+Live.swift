import KiwiDeskCore

/// The rows the pill owes for a stored setting changed live and
/// not saved (#2262). Core judges which leaves count
/// (`KiwiCore.savedSettingsBehindLive`); these rows only narrate
/// them, through the readout every other row takes.
extension SettingsDiffRowSource {
    /// The instance discriminator of every live row.
    static let liveInstance = "live"

    /// Saved → live, one row per setting, leaving out a setting
    /// the draft itself edits: the edit is the newer act and its
    /// own row narrates it.
    static func liveRows(
        for model: SettingsModel,
        leaving edited: [SettingKey]
    ) -> [SettingsDiffRow] {
        guard model.target == .live,
            let saved = model.savedBehindLive
        else { return [] }
        var savedConfig = model.cleanConfig
        savedConfig.settings = saved
        let diff = SettingsDraftDiff.between(
            config: model.cleanConfig,
            cleanConfig: savedConfig
        )
        let skip = Set(edited)
        return diff.changedSettings.filter { !skip.contains($0) }
            .flatMap { key in
                SettingsValueReadout.rows(
                    for: key,
                    old: savedConfig,
                    new: model.cleanConfig
                ).map { row in
                    var row = row
                    row.id += "#" + liveInstance
                    row.section = .live
                    return row
                }
            }
    }
}

extension SettingsModel {
    /// Whether a stored setting is live but not saved — a reason
    /// the pill appears, with its rows in the pill's list.
    var liveUnsaved: Bool {
        !SettingsDiffRowSource.liveRows(for: self, leaving: []).isEmpty
    }
}
