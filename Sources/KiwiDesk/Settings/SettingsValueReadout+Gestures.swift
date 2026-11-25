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
        old: LayerGestures,
        new: LayerGestures,
        shortcutBase: ShortcutBase
    ) -> [SettingsDiffRow] {
        // `default` first, then the rest by name.
        let layers = Set(old.layers).union(new.layers).sorted {
            let first = KeyLayer.defaultName
            return $0 == first || ($1 != first && $0 < $1)
        }
        return layers.flatMap { layer in
            gestureRows(
                old: old[layer],
                new: new[layer],
                scope: GestureSeedScope(
                    shortcutBase: shortcutBase,
                    layer: layer
                )
            )
        }
    }

    /// One layer's rows.
    private static func gestureRows(
        old: GestureMap,
        new: GestureMap,
        scope: GestureSeedScope
    ) -> [SettingsDiffRow] {
        let changed = Set(old.entries.keys).union(new.entries.keys)
            .filter { old[$0] != new[$0] }
            .sorted()
        let before = {
            GestureListEdits.action(of: $0, in: old, scope: scope)
        }
        let after = {
            GestureListEdits.action(of: $0, in: new, scope: scope)
        }
        let at = { LayerGestureKey(scope.layer, $0) }
        let name = { rowName($0, layer: scope.layer) }
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
                    from: at(from),
                    to: at(key)
                ).spelling,
                label: GestureListWords.value(action, on: key.input),
                old: name(from),
                new: name(key)
            )
            row.subject = subject(at(key))
            row.pairedSubject = subject(at(from))
            rows.append(row)
        }
        for key in changed where !moved.contains(key) {
            let words = words(
                of: key,
                named: name(key),
                before(key),
                after(key)
            )
            var row = SettingsDiffRow.change(
                .shortcuts(.gestureBindings),
                instance: GestureRowInstance.key(at(key)).spelling,
                label: words.label,
                old: words.old,
                new: words.new
            )
            row.subject = subject(at(key))
            rows.append(row)
        }
        return rows
    }

    /// A row's name: its gesture and keys, and its layer where that
    /// is not the default one (#3535).
    static func rowName(_ key: GestureKey, layer: String) -> String {
        let row = GestureListWords.rowName(key)
        guard layer != KeyLayer.defaultName else { return row }
        return L(
            "shortcuts.gestures.layer_row",
            "%1$@ on \u{201C}%2$@\u{201D}",
            row,
            layer
        )
    }

    /// A key's row words: where one direction alone changed, that
    /// direction and its two actions (#3321), so an arm edit never
    /// reads "Per direction → Per direction"; else the row's two
    /// values.
    private static func words(
        of key: GestureKey,
        named row: String,
        _ before: GestureAction?,
        _ after: GestureAction?
    ) -> (label: String, old: String, new: String) {
        let input = key.input
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
    private static func subject(_ key: LayerGestureKey) -> ReachSubject {
        ReachSubject(family: .gesture, key: key.spelling)
    }
}
