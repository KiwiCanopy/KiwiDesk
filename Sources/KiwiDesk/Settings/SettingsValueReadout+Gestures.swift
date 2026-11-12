import KiwiDeskCore

/// The gesture cards' diff rows (#3183): one row per key whose
/// stored entry changed, named by its gesture and keys. A re-key
/// writes two keys together — the old one left, the new one bound
/// to the same action — so it narrates as ONE row naming both,
/// whose ↺ takes both back (gui.md ▸ A diff row's ↺).
extension SettingsValueReadout {
    /// The separator of a move row's instance: no key spelling
    /// holds it.
    static let gestureMoveSeparator: Character = "|"

    static func gestureRows(
        old: GestureMap,
        new: GestureMap
    ) -> [SettingsDiffRow] {
        let changed = Set(old.entries.keys).union(new.entries.keys)
            .filter { old[$0] != new[$0] }
            .sorted()
        let before = { GestureListEdits.action(of: $0, in: old) }
        let after = { GestureListEdits.action(of: $0, in: new) }
        var left = changed.filter { before($0) != nil && after($0) == nil }
        var rows: [SettingsDiffRow] = []
        var moved: Set<GestureKey> = []
        for key in changed where before(key) == nil {
            guard let action = after(key),
                let index = left.firstIndex(where: { before($0) == action })
            else { continue }
            let from = left.remove(at: index)
            moved.formUnion([from, key])
            rows.append(
                .change(
                    .shortcuts(.gestureBindings),
                    instance: from.spelling
                        + String(gestureMoveSeparator) + key.spelling,
                    label: GestureListWords.value(action),
                    old: GestureListWords.rowName(from),
                    new: GestureListWords.rowName(key)
                )
            )
        }
        for key in changed where !moved.contains(key) {
            rows.append(
                .change(
                    .shortcuts(.gestureBindings),
                    instance: key.spelling,
                    label: GestureListWords.rowName(key),
                    old: GestureListWords.value(before(key)),
                    new: GestureListWords.value(after(key))
                )
            )
        }
        return rows
    }
}
