import KiwiDeskCore

/// The rows the pill owes for a stored setting changed live and
/// not saved (#2262). Core judges which leaves count and hands over
/// both sides of one reading (`KiwiCore.unsavedLiveSettings`); these
/// rows only narrate them, through the readout every other row
/// takes, and never diff against the draft's own baseline.
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
        guard let unsaved = model.unsavedLive else { return [] }
        var saved = model.cleanConfig
        saved.settings = unsaved.saved
        var live = model.cleanConfig
        live.settings = unsaved.live
        let diff = SettingsDraftDiff.between(
            config: live,
            cleanConfig: saved
        )
        let skip = Set(edited)
        return diff.changedSettings.filter { !skip.contains($0) }
            .flatMap { key in
                SettingsValueReadout.rows(
                    for: key,
                    old: saved,
                    new: live
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
    /// Asks Core again — the one writer of `unsavedLive` and
    /// `liveUnsaved`. Owed wherever the live settings or the
    /// draft's baseline can have moved: the seed, a window-key
    /// return, an outside write the draft adopts. Only the live
    /// target lists live rows: a stored profile is another file.
    func refreshUnsavedLive() {
        unsavedLive =
            target == .live && !editingLua
            ? core.unsavedLiveSettings() : nil
        liveUnsaved = !SettingsDiffRowSource.liveRows(
            for: self,
            leaving: []
        ).isEmpty
    }
}
