import KiwiDeskCore

/// The shortcuts panel's gestures (#1873 ▸ Ruling 2026-11-15, the
/// hybrid): a gesture whose action has a row is a badge on it, and
/// every other bound gesture is a row of one "Gestures" group —
/// grabs, the wheel, an app, custom Lua, a lone direction and
/// KiwiHub's own openers — so each binding appears exactly once.
/// Read from the live resolved bindings, never the seeds alone.
extension ShortcutsReferenceBuilder {
    /// One motion a binding runs: the Lua it reaches toward one way,
    /// or the whole of a gesture with no way.
    struct GestureReach {
        let badge: ShortcutGestureBadge
        let lua: String
        /// The words a "Gestures" row reads.
        let label: String
    }

    static func withGestures(
        _ reference: ShortcutsReference,
        bindings: [GestureKey: GestureAction],
        name: (LuaAction) -> String
    ) -> ShortcutsReference {
        var open = reaches(bindings, name: name)
        var out = reference
        func attach(_ rows: inout [ShortcutRow]) {
            for index in rows.indices {
                rows[index] = attached(rows[index], from: &open)
            }
        }
        for index in out.controls.indices { attach(&out.controls[index].rows) }
        for index in out.groups.indices { attach(&out.groups[index].rows) }
        attach(&out.inactive)
        attach(&out.apps)
        attach(&out.custom)
        let left = gestureRows(open, bindings: bindings)
        if !left.isEmpty {
            out.groups.append(
                ShortcutSubgroup(
                    title: L("shortcuts.panel.gestures", "Gestures"),
                    rows: left
                )
            )
        }
        return out
    }

    /// Every motion of every binding, a family's per direction.
    static func reaches(
        _ bindings: [GestureKey: GestureAction],
        name: (LuaAction) -> String
    ) -> [GestureReach] {
        bindings.keys.sorted().flatMap { key -> [GestureReach] in
            guard let action = bindings[key] else { return [] }
            if case .grab(let grab) = action {
                return [
                    GestureReach(
                        badge: ShortcutGestureBadge(key: key, direction: nil),
                        lua: "",
                        label: GestureListWords.grab(grab)
                    )
                ]
            }
            guard !key.input.directions.isEmpty else {
                guard case .run(let run) = action else { return [] }
                return [
                    GestureReach(
                        badge: ShortcutGestureBadge(key: key, direction: nil),
                        lua: run.lua,
                        label: name(run)
                    )
                ]
            }
            return key.input.directions.compactMap { direction in
                let label: String
                let lua: String
                switch action.step(toward: direction) {
                case .family(let family):
                    lua = family.lua(direction)
                    label = GestureListWords.family(family)
                case .lua(let run):
                    lua = run.lua
                    label = name(run)
                case nil: return nil
                }
                return GestureReach(
                    badge: ShortcutGestureBadge(
                        key: key,
                        direction: direction
                    ),
                    lua: lua,
                    label: label
                )
            }
        }
    }

    /// `row` with the badges of the motions that run its action
    /// taken from `open`.
    private static func attached(
        _ row: ShortcutRow,
        from open: inout [GestureReach]
    ) -> ShortcutRow {
        var row = row
        let ids = Set([row.id] + row.members.map(\.id))
        let hits = open.filter { !$0.lua.isEmpty && ids.contains($0.lua) }
        guard !hits.isEmpty else { return row }
        open.removeAll { !$0.lua.isEmpty && ids.contains($0.lua) }
        var badges: [ShortcutGestureBadge] = []
        let byKey = Dictionary(grouping: hits, by: \.badge.key)
        // A gesture reaching the row more than one way — a family
        // whose up and left both step to the next Space, or every way
        // of a folded set — wears its glyph once, with no way.
        for (key, reached) in byKey {
            if reached.count > 1 {
                badges.append(ShortcutGestureBadge(key: key, direction: nil))
            } else {
                badges += reached.map(\.badge)
            }
        }
        row.gestures = badges.sorted(by: ShortcutGestureBadge.moreSpecific)
        return row
    }

    /// The motions no row holds, one row per binding where a family
    /// runs every way, else one per way.
    private static func gestureRows(
        _ open: [GestureReach],
        bindings: [GestureKey: GestureAction]
    ) -> [ShortcutRow] {
        let byKey = Dictionary(grouping: open, by: \.badge.key)
        return byKey.keys.sorted().flatMap { key -> [ShortcutRow] in
            let reached = byKey[key] ?? []
            if case .family(let family) = bindings[key],
                reached.count == key.input.directions.count
            {
                return [
                    gestureRow(
                        GestureListWords.family(family),
                        ShortcutGestureBadge(key: key, direction: nil)
                    )
                ]
            }
            return reached.map { gestureRow($0.label, $0.badge) }
        }
    }

    private static func gestureRow(
        _ label: String,
        _ badge: ShortcutGestureBadge
    ) -> ShortcutRow {
        var row = ShortcutRow(
            id: "gesture:" + badge.id,
            label: label,
            combo: ""
        )
        row.gestures = [badge]
        return row
    }
}
