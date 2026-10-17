import KiwiDeskCore

/// The two parts of the diff list (#2262).
enum SettingsDiffSection: Hashable {
    /// The draft's edits and the profile drift.
    case draft
    /// A stored setting changed live, outside Settings, and not
    /// saved: narrated saved → live.
    case live
}

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
    /// The jump lands on the area's root rather than the key's
    /// labelled control — for a row whose subject no control
    /// renders (#1197).
    var jumpsToAreaRoot = false
    /// Which part of the list the row is drawn in.
    var section: SettingsDiffSection = .draft
    /// A live row's unsaved leaves, as keep ids — what its Keep
    /// writes (#2368); empty on a draft row.
    var keepIDs: [String] = []

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
        note: String,
        areaRoot: Bool = false
    ) -> SettingsDiffRow {
        SettingsDiffRow(
            id: rowID(key, instance: instance),
            key: key,
            label: label,
            oldValue: nil,
            newValue: nil,
            changeNote: note,
            jumpsToAreaRoot: areaRoot
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
