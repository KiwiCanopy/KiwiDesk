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
                new: new.floatRules,
                family: .float
            )
        case .floatRulesPattern:
            // A `[String]` has no `.pattern` leaf for the walk to
            // book — changes land on the list key; narrating the
            // same membership diff keeps this key total.
            return appRulesListNotes(
                census,
                base: label(
                    for: SettingKey.appRules(.floatRules)
                ),
                old: old.floatRules,
                new: new.floatRules,
                family: .float
            )
        case .ignoreRules:
            return appRulesListNotes(
                census,
                base: L(
                    "diff.label.ignore_rule",
                    "Ignore rule"
                ),
                old: old.ignoreRules,
                new: new.ignoreRules,
                family: nil
            )
        case .floatAutomatically:
            return [
                .change(
                    census,
                    label: label(for: census),
                    old: AutoFloatWords.value(old.floatAutomatically),
                    new: AutoFloatWords.value(new.floatAutomatically)
                )
            ]
        case .tileRules:
            return appRulesListNotes(
                census,
                base: label(for: census),
                old: old.tileRules,
                new: new.tileRules,
                family: .tile
            )
        case .appRulesAddSpace, .appRulesAddFloat, .spaceRuleDelete,
            .floatRuleDelete, .appRulesAddTile, .tileRuleDelete:
            // No model path — never booked by the diff.
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
            var row = SettingsDiffRow.change(
                census,
                instance: app,
                label: instanceLabel(base, app),
                old: old[app]?.raw ?? unset,
                new: new[app]?.raw ?? unset
            )
            row.subject = ReachSubject(
                family: .space,
                key: RuleFamily.space.key(app)
            )
            return row
        }
    }

    /// Structural notes for a rule list: one Added/Removed row
    /// per entry that joined or left, counted so duplicate
    /// entries each match once.
    private static func appRulesListNotes(
        _ census: SettingKey,
        base: String,
        old: [String],
        new: [String],
        // Required, so a list another profile's reach can name never
        // forgets its subject (#792): nil only where none can.
        family: RuleFamily?
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
        // The copy count rides the instance so DUPLICATE list
        // entries (each matched once above) still mint distinct
        // row ids inside one ForEach (#792's revert parses it).
        let instances =
            ListEntryInstance.minted(remaining, added: true)
            + ListEntryInstance.minted(removed, added: false)
        for instance in instances {
            var row = SettingsDiffRow.note(
                census,
                instance: instance.spelled,
                label: instanceLabel(base, instance.entry),
                note: instance.added ? addedNote : removedNote
            )
            row.subject = family.map {
                ReachSubject(
                    family: $0,
                    key: $0.subject(ofRule: instance.entry)
                )
            }
            rows.append(row)
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
