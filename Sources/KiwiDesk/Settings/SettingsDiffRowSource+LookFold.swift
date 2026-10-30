import KiwiDeskCore

/// Simple's one look row (#2745 ruling): on Simple, every draft row
/// a look pick reaches folds into "Changes to the look", whose ↺
/// takes the pick back (`ShelfLook.unpicked`). Advanced keeps a row
/// per setting, save the rows a staged "Use the shared look" painted,
/// which fold into its switch row on either root (#2820).
extension SettingsDiffRowSource {
    /// `rows` with Simple's look rows folded into one, where the
    /// first of them stood; unchanged on Advanced.
    static func lookFolded(
        _ rows: [SettingsDiffRow],
        for model: SettingsModel
    ) -> [SettingsDiffRow] {
        let rows = sharePaintFolded(rows, for: model)
        guard model.showsSimple else { return rows }
        let keys = lookKeys(of: model)
        let folds = { (row: SettingsDiffRow) in foldsIntoLook(row, keys) }
        guard let first = rows.firstIndex(where: folds) else { return rows }
        var folded = rows.filter { !folds($0) }
        folded.insert(lookRow, at: first)
        return folded
    }

    /// `rows` without those a staged "Use the shared look" painted
    /// (#2820): its switch row stands for them, and its ↺ takes the
    /// paint and the switch back together, so one leaf cannot be
    /// reverted alone and land as an edit of the shared look.
    static func sharePaintFolded(
        _ rows: [SettingsDiffRow],
        for model: SettingsModel
    ) -> [SettingsDiffRow] {
        guard case .use(_, let base) = model.lookShare else { return rows }
        var unpainted = model.config
        unpainted.settings = ShelfLook.unpicked(
            model.config.settings,
            to: base
        )
        let keys = Set(changed(model.config, model))
            .subtracting(changed(unpainted, model))
        return rows.filter { !foldsIntoLook($0, keys) }
    }

    /// The changed keys the look row stands for: those taking the
    /// pick back would leave unchanged, so the row's members are
    /// exactly what its ↺ reverts.
    static func lookKeys(of model: SettingsModel) -> Set<SettingKey> {
        var unpicked = model.config
        unpicked.settings = ShelfLook.unpicked(
            model.config.settings,
            to: model.cleanConfig.settings
        )
        return Set(changed(model.config, model))
            .subtracting(changed(unpicked, model))
    }

    /// A row among `keys`, or the master of a group with a member
    /// among them. `keys` comes from the draft diff, and a live row
    /// never carries a setting the draft edits (`liveRows`), so
    /// only draft rows can match.
    static func foldsIntoLook(
        _ row: SettingsDiffRow,
        _ keys: Set<SettingKey>
    ) -> Bool {
        keys.contains(row.key)
            || SettingKey.summaryGroups[row.key, default: []]
                .contains(where: keys.contains)
    }

    private static func changed(
        _ config: GuiConfig,
        _ model: SettingsModel
    ) -> [SettingKey] {
        SettingsDraftDiff.between(
            config: config,
            cleanConfig: model.cleanConfig,
            luaSource: model.luaSource,
            cleanLuaSource: model.cleanLuaSource
        ).changedSettings
    }

    private static var lookRow: SettingsDiffRow {
        var row = SettingsDiffRow.note(
            .colours(.lookApply),
            label: L("diff.look_changes", "Changes to the look"),
            note: L("diff.note.edited", "Edited")
        )
        row.revert = .lookChanges
        return row
    }
}
