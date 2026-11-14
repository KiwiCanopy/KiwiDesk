import KiwiDeskCore

/// The gesture cards' diff rows (#3183): one row per key whose
/// stored entry changed, named by its gesture and keys. A re-key
/// writes two keys together — the old one left, the new one bound
/// to the same action — so it narrates as ONE row naming both,
/// whose ↺ takes both back (gui.md ▸ A diff row's ↺). A move is
/// read from the map, a key that lost an action beside one that
/// gained it, so a row deleted and another added with that action
/// reads as a move too — its ↺ still takes back exactly what
/// changed.
extension SettingsValueReadout {
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
            var row = SettingsDiffRow.change(
                .shortcuts(.gestureBindings),
                instance: GestureRowInstance.move(
                    from: from,
                    to: key
                ).spelling,
                label: GestureListWords.value(action, on: key.input),
                old: GestureListWords.rowName(from),
                new: GestureListWords.rowName(key)
            )
            row.subject = subject(key)
            row.pairedSubject = subject(from)
            rows.append(row)
        }
        for key in changed where !moved.contains(key) {
            let words = words(of: key, before(key), after(key))
            var row = SettingsDiffRow.change(
                .shortcuts(.gestureBindings),
                instance: GestureRowInstance.key(key).spelling,
                label: words.label,
                old: words.old,
                new: words.new
            )
            row.subject = subject(key)
            rows.append(row)
        }
        return rows
    }

    /// A key's row words: where one direction alone changed, that
    /// direction and its two actions (#3321), so an arm edit never
    /// reads "Per direction → Per direction"; else the row's two
    /// values.
    private static func words(
        of key: GestureKey,
        _ before: GestureAction?,
        _ after: GestureAction?
    ) -> (label: String, old: String, new: String) {
        let input = key.input
        let row = GestureListWords.rowName(key)
        if let was = GestureListEdits.arms(of: before, on: input),
            let now = GestureListEdits.arms(of: after, on: input)
        {
            let moved = input.directions.filter { was[$0] != now[$0] }
            if moved.count == 1, let direction = moved.first {
                return (
                    L(
                        "shortcuts.gestures.direction_action",
                        "%1$@, %2$@",
                        row,
                        GestureListWords.direction(direction)
                    ),
                    armWords(was[direction]),
                    armWords(now[direction])
                )
            }
        }
        return (
            row,
            GestureListWords.value(before, on: input),
            GestureListWords.value(after, on: input)
        )
    }

    private static func armWords(_ arm: LuaAction?) -> String {
        GestureListWords.value(arm.map { .run($0) })
    }

    /// The reach subject a gesture row folds on (#3225): its key; a
    /// move folds on both of its keys.
    private static func subject(_ key: GestureKey) -> ReachSubject {
        ReachSubject(family: .gesture, key: key.spelling)
    }
}
