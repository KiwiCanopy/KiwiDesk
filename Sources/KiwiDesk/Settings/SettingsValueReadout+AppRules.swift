import KiwiDeskCore

/// App Rules settings diff readout rows for SettingsValueReadout.
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
            return []
        }
    }

    /// Diff rows for application space routing map changes.
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
        // The enumeration index rides the instance so DUPLICATE
        // list entries (each matched once above) still mint
        // distinct row ids inside one ForEach.
        for (index, entry) in remaining.enumerated() {
            rows.append(
                .note(
                    census,
                    instance: "+" + entry + "#\(index)",
                    label: instanceLabel(base, entry),
                    note: addedNote
                )
            )
        }
        for (index, entry) in removed.enumerated() {
            rows.append(
                .note(
                    census,
                    instance: "-" + entry + "#\(index)",
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
