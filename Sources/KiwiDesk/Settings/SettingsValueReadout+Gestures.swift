import KiwiDeskCore

/// The gesture cards' diff rows (#3183): one row per key whose
/// stored entry changed, named by its gesture and keys, its ↺
/// taking that key alone.
extension SettingsValueReadout {
    static func gestureRows(
        old: GestureMap,
        new: GestureMap
    ) -> [SettingsDiffRow] {
        let keys = Set(old.entries.keys).union(new.entries.keys)
        return keys.sorted().compactMap { key in
            let before = GestureListEdits.action(of: key, in: old)
            let after = GestureListEdits.action(of: key, in: new)
            guard before != after else { return nil }
            return .change(
                .shortcuts(.gestureBindings),
                instance: key.spelling,
                label: GestureListWords.rowName(key),
                old: GestureListWords.value(before),
                new: GestureListWords.value(after)
            )
        }
    }
}
