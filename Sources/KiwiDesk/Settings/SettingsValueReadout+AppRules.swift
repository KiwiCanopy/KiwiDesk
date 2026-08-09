import KiwiDeskCore

/// App Rules rows. The app→space map narrates per app as
/// "— → Mail"-style value pairs of space names; the two rule
/// lists (float, ignore) narrate membership as structural
/// notes per entry, the instance being the entry exactly as
/// stored.
extension SettingsValueReadout {
    static func appRulesRows(
        _ key: AppRulesKey,
        old: GuiConfig,
        new: GuiConfig
    ) -> [SettingsDiffRow] {
        let census = SettingKey.appRules(key)
        switch key {
        case .appRules:
            return appRulesSpaceRows(
                census,
                old: old.appRules,
                new: new.appRules
            )
        case .floatRules:
            return appRulesListNotes(
                census,
                base: label(for: census),
                old: old.floatRules,
                new: new.floatRules
            )
        case .floatRulesPattern:
            // The pattern facet edits entries of
            // `config.floatRules` — a `[String]` has no
            // `.pattern` leaf for the walk to book, so changes
            // land on the list key above. Narrating the same
            // membership diff keeps this key total; the rows
            // carry the list key's label as their base.
            return appRulesListNotes(
                census,
                base: label(
                    for: SettingKey.appRules(.floatRules)
                ),
                old: old.floatRules,
                new: new.floatRules
            )
        case .ignoreRules:
            return appRulesListNotes(
                census,
                base: L(
                    "diff.label.ignore_rule",
                    "Ignore rule"
                ),
                old: old.ignoreRules,
                new: new.ignoreRules
            )
        case .appRulesAdd, .appRulesDelete:
            // no model path — never booked by the diff
            return []
        }
    }

    /// One value-pair row per re-ruled app: the space it opens
    /// in, with the unset dash where the rule appeared or was
    /// removed.
    private static func appRulesSpaceRows(
        _ census: SettingKey,
        old: [String: SpaceID],
        new: [String: SpaceID]
    ) -> [SettingsDiffRow] {
        let base = label(for: census)
        let touched = Set(old.keys).union(new.keys)
            .filter { old[$0] != new[$0] }
            .sorted()
        return touched.map { app in
            .change(
                census,
                instance: app,
                label: instanceLabel(base, app),
                old: old[app]?.raw ?? unset,
                new: new[app]?.raw ?? unset
            )
        }
    }

    /// Structural notes for a rule list: one Added/Removed row
    /// per entry that joined or left, counted so duplicate
    /// entries each match once.
    private static func appRulesListNotes(
        _ census: SettingKey,
        base: String,
        old: [String],
        new: [String]
    ) -> [SettingsDiffRow] {
        var remaining = new
        var removed: [String] = []
        for entry in old {
            if let index = remaining.firstIndex(of: entry) {
                remaining.remove(at: index)
            } else {
                removed.append(entry)
            }
        }
        var rows: [SettingsDiffRow] = []
        for entry in remaining {
            rows.append(
                .note(
                    census,
                    instance: "+" + entry,
                    label: instanceLabel(base, entry),
                    note: addedNote
                )
            )
        }
        for entry in removed {
            rows.append(
                .note(
                    census,
                    instance: "-" + entry,
                    label: instanceLabel(base, entry),
                    note: removedNote
                )
            )
        }
        // A pure reorder moves no membership; one edited note
        // keeps the key total for the readout totality guard.
        if rows.isEmpty, old != new {
            rows.append(
                .note(census, label: base, note: editedNote)
            )
        }
        return rows
    }
}
