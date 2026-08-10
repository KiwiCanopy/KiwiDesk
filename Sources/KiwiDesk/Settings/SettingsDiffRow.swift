import KiwiDeskCore

/// One display-ready row of the draft diff (#678 turn 9, digest
/// §1.1): the label the census names the setting by, and the
/// old → new values where the readout can state them. Three
/// surfaces render these rows — the detail panel's "CHANGED IN
/// THIS DRAFT" list, Home's unsaved-changes popover, and (pass
/// 6) nothing else claims them — all through
/// `SettingsDiffRowsView`, so the draft has one row vocabulary.
struct SettingsDiffRow: Identifiable, Hashable {
    /// Stable identity: the census id, plus an instance
    /// discriminator where one key draws several rows (a
    /// per-space override books one row per touched space).
    var id: String
    /// The census key the row belongs to — the jump target's
    /// anchor and the popover's area grouping both read it.
    var key: SettingKey
    /// Composed, localized ("Outer gap", "Monocle · thickness").
    var label: String
    /// Display strings. Nil when the change has no scalar to
    /// state (an added space, an edited binding list) — the row
    /// then renders its `changeNote` alone.
    var oldValue: String?
    var newValue: String?
    /// The valueless rows' one-word narration ("Added",
    /// "Removed", "Edited"), localized. Nil when the value pair
    /// carries the story.
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
