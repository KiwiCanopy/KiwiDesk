import KiwiDeskCore

/// Display-ready row of the draft diff (`SettingsDiffRowsView`, #678 turn 9).
struct SettingsDiffRow: Identifiable, Hashable {
    /// Stable identity: census id plus instance discriminator.
    var id: String
    /// Census key the row belongs to.
    var key: SettingKey
    /// Localized label ("Outer gap", "Monocle · thickness").
    var label: String
    /// Display strings; nil when the change has no scalar to
    /// state — the row then renders its `changeNote` alone.
    var oldValue: String?
    var newValue: String?
    /// Localized change description for structural modifications.
    var changeNote: String?

    /// A plain value-pair row.
    static func change(
        _ key: SettingKey,
        instance: String? = nil,
        label: String,
        old: String?,
        new: String?
    ) -> SettingsDiffRow {
        SettingsDiffRow(
            id: rowID(key, instance: instance),
            key: key,
            label: label,
            oldValue: old,
            newValue: new,
            changeNote: nil
        )
    }

    /// A row whose change is structural rather than scalar.
    static func note(
        _ key: SettingKey,
        instance: String? = nil,
        label: String,
        note: String
    ) -> SettingsDiffRow {
        SettingsDiffRow(
            id: rowID(key, instance: instance),
            key: key,
            label: label,
            oldValue: nil,
            newValue: nil,
            changeNote: note
        )
    }

    private static func rowID(
        _ key: SettingKey,
        instance: String?
    ) -> String {
        guard let instance else { return key.id }
        return key.id + "#" + instance
    }
}
