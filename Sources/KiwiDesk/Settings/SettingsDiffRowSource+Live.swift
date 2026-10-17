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
        let owners = leafOwners(unsaved, saved: saved)
        return diff.changedSettings.filter { !skip.contains($0) }
            .flatMap { key in
                SettingsValueReadout.rows(
                    for: key,
                    old: saved,
                    new: live
                ).map { row in
                    var row = row
                    row.keepIDs = owners[row.id, default: []].sorted()
                    row.id += "#" + liveInstance
                    row.section = .live
                    return row
                }
            }
    }

    /// Which unsaved leaves each row carries, by row id: a leaf
    /// belongs to every row its own change narrates, so one key's
    /// rows (a setting per layout) keep apart.
    private static func leafOwners(
        _ unsaved: UnsavedLiveSettings,
        saved: GuiConfig
    ) -> [String: [String]] {
        var owners: [String: [String]] = [:]
        for (id, settings) in unsaved.leaves {
            var one = saved
            one.settings = settings
            let keys = SettingsDraftDiff.between(
                config: one,
                cleanConfig: saved
            ).changedSettings
            for key in keys {
                for row in SettingsValueReadout.rows(
                    for: key,
                    old: saved,
                    new: one
                ) {
                    owners[row.id, default: []].append(id)
                }
            }
        }
        return owners
    }
}

extension SettingsModel {
    /// Keeps a live row's leaves into the live profile through
    /// Core's keep (#2368), then asks Core again; the write moves
    /// an open draft's baseline through `adoptLiveWrite`.
    /// Leaves it could not write stay listed with their reason in
    /// `liveKeepRefusals`.
    @discardableResult
    func keepLive(_ ids: [String]) -> LiveKeepOutcome? {
        guard target == .live, !ids.isEmpty else { return nil }
        let outcome = core.keepUnsavedLive(ids)
        refreshUnsavedLive()
        liveKeepRefusals = outcome.refused
        return outcome
    }

    /// Asks Core again — the one writer of `unsavedLive` and
    /// `liveUnsaved`. Owed wherever the live settings or the
    /// draft's baseline can have moved: the seed, a window-key
    /// return, an outside write the draft adopts. Only the live
    /// target lists live rows: a stored profile is another file.
    func refreshUnsavedLive() {
        liveKeepRefusals = [:]
        unsavedLive =
            target == .live && !editingLua
            ? core.unsavedLiveSettings() : nil
        liveUnsaved = !SettingsDiffRowSource.liveRows(
            for: self,
            leaving: []
        ).isEmpty
    }
}
