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
        /// What leads that row (#3380): a family's or a command's
        /// symbol, the Lua mark, or the app it opens.
        var icon: ShortcutGlyph? = nil
        var bundleID: String? = nil
    }

    static func withGestures(
        _ reference: ShortcutsReference,
        bindings: [GestureKey: GestureAction],
        natural: (GestureInput) -> Bool = { _ in true },
        name: (LuaAction) -> String,
        icon: (LuaAction) -> ShortcutGlyph? = { _ in nil }
    ) -> ShortcutsReference {
        var open = reaches(
            bindings,
            natural: natural,
            name: name,
            icon: icon
        )
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
        natural: (GestureInput) -> Bool,
        name: (LuaAction) -> String,
        icon: (LuaAction) -> ShortcutGlyph? = { _ in nil }
    ) -> [GestureReach] {
        func reach(
            _ badge: ShortcutGestureBadge,
            _ run: LuaAction
        ) -> GestureReach {
            // An app shows its own icon; the user's Lua its symbol or
            // the Lua mark; a command its catalogue glyph.
            let app =
                run.kind == .application
                ? KeybindingCatalog.appBundleID(from: run.lua) : nil
            var glyph: ShortcutGlyph?
            if app == nil {
                let command = run.kind == .custom ? nil : icon(run)
                glyph = command ?? ownIcon(run.meta)
            }
            return GestureReach(
                badge: badge,
                lua: run.lua,
                label: name(run),
                icon: glyph,
                bundleID: app
            )
        }
        return bindings.keys.sorted().flatMap { key -> [GestureReach] in
            guard let action = bindings[key] else { return [] }
            if case .grab(let grab) = action {
                return [
                    GestureReach(
                        badge: ShortcutGestureBadge(key: key, direction: nil),
                        lua: "",
                        label: GestureListWords.grab(grab),
                        icon: .symbol(grabIcon(grab))
                    )
                ]
            }
            guard !key.input.directions.isEmpty else {
                guard case .run(let run) = action else { return [] }
                return [
                    reach(
                        ShortcutGestureBadge(key: key, direction: nil),
                        run
                    )
                ]
            }
            return key.input.directions.compactMap { direction in
                // The way the step runs, Natural applied, so a badge
                // sits on the row that fires (`resolvedStep`).
                guard
                    let (step, way) = action.resolvedStep(
                        toward: direction,
                        natural: natural(key.input)
                    )
                else { return nil }
                let badge = ShortcutGestureBadge(
                    key: key,
                    direction: direction
                )
                switch step {
                case .family(let family):
                    return GestureReach(
                        badge: badge,
                        lua: family.lua(way),
                        label: GestureListWords.family(family),
                        icon: .symbol(familyIcon(for: family))
                    )
                case .lua(let run):
                    return reach(badge, run)
                }
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
        // of a folded set — wears its glyph once, with no way; both
        // ways of one axis draw that axis (#3380).
        for (key, reached) in byKey {
            if reached.count > 1 {
                let ways = Set(reached.compactMap(\.badge.direction))
                badges.append(
                    ShortcutGestureBadge(
                        key: key,
                        direction: nil,
                        axis: .of(ways)
                    )
                )
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
                        GestureReach(
                            badge: ShortcutGestureBadge(
                                key: key,
                                direction: nil
                            ),
                            lua: "",
                            label: GestureListWords.family(family),
                            icon: .symbol(familyIcon(for: family))
                        )
                    )
                ]
            }
            return reached.map(gestureRow)
        }
    }

    /// A "Gestures" row, led by its reach's symbol or app (#3380).
    private static func gestureRow(_ reach: GestureReach) -> ShortcutRow {
        var row = ShortcutRow(
            id: "gesture:" + reach.badge.id,
            label: reach.label,
            combo: "",
            icon: reach.icon,
            bundleID: reach.bundleID
        )
        row.gestures = [reach.badge]
        return row
    }
}
