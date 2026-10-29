import KiwiDeskCore

/// Simple's one look row (#2745 ruling): on Simple, every draft row
/// a look paints folds into "Changes to the look", whose ↺ takes
/// them all back. Advanced keeps a row per setting.
extension SettingsDiffRowSource {
    /// `rows` with Simple's look rows folded into one, where the
    /// first of them stood; unchanged on Advanced.
    static func lookFolded(
        _ rows: [SettingsDiffRow],
        for model: SettingsModel
    ) -> [SettingsDiffRow] {
        guard model.showsSimple,
            let first = rows.firstIndex(where: foldsIntoLook)
        else { return rows }
        var folded = rows.filter { !foldsIntoLook($0) }
        folded.insert(lookRow, at: first)
        return folded
    }

    /// The draft rows Simple's look row stands for.
    static func lookMembers(
        of model: SettingsModel
    ) -> [SettingsDiffRow] {
        rows(for: model, foldingLook: false).filter(foldsIntoLook)
    }

    /// A draft row a look pick writes: a look-painted path, or the
    /// origin the pick records.
    static func foldsIntoLook(_ row: SettingsDiffRow) -> Bool {
        row.section == .draft
            && (SimpleCoverage.isLookPainted(row.key)
                || row.key == .colours(.lookOrigin))
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
