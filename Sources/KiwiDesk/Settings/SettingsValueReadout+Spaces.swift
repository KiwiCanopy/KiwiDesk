import KiwiDeskCore

/// Spaces settings diff readout rows for SettingsValueReadout.
extension SettingsValueReadout {
    static func spacesRows(
        _ key: SpacesKey,
        old: GuiConfig,
        new: GuiConfig
    ) -> [SettingsDiffRow] {
        let census = SettingKey.spaces(key)
        switch key {
        case .spaceList:
            return spacesListRows(census, old: old, new: new)
        case .spacesName:
            return spacesRenameRows(census, old: old, new: new)
        case .spaceModes:
            return spacesModeRows(census, old: old, new: new)
        case .spaceIcon:
            return spacesIconRows(census, old: old, new: new)
        case .fallbackSpace:
            return [
                .change(
                    census,
                    label: L(
                        "diff.label.fallback_space",
                        "Fallback Space"
                    ),
                    old: old.fallbackSpace?.raw ?? unset,
                    new: new.fallbackSpace?.raw ?? unset
                )
            ]
        case .spaceOverrideResetActive, .spaceOverrideResetAll,
            .spacesDelete:
            // "(action)" ids are skipped by `censusBases()` — no
            // change ever resolves to them.
            return []
        }
    }

    /// Structural diff rows for spaces list changes.
    private static func spacesListRows(
        _ census: SettingKey,
        old: GuiConfig,
        new: GuiConfig
    ) -> [SettingsDiffRow] {
        let base = L("diff.label.space_list", "Spaces")
        let oldSet = Set(old.spaces)
        let newSet = Set(new.spaces)
        var rows: [SettingsDiffRow] = []
        for space in new.spaces where !oldSet.contains(space) {
            rows.append(
                .note(
                    census,
                    instance: space.raw,
                    label: instanceLabel(base, space.raw),
                    note: addedNote
                )
            )
        }
        for space in old.spaces where !newSet.contains(space) {
            rows.append(
                .note(
                    census,
                    instance: space.raw,
                    label: instanceLabel(base, space.raw),
                    note: removedNote
                )
            )
        }
        if rows.isEmpty, old.spaces != new.spaces {
            rows.append(
                .note(census, label: base, note: editedNote)
            )
        }
        return rows
    }

    /// Diff rows for space renames (`GuiConfig.renameSpace`).
    private static func spacesRenameRows(
        _ census: SettingKey,
        old: GuiConfig,
        new: GuiConfig
    ) -> [SettingsDiffRow] {
        guard old.spaces.count == new.spaces.count else {
            return []
        }
        let base = L("diff.label.space_name", "Space name")
        return zip(old.spaces, new.spaces)
            .filter { $0.0 != $0.1 }
            .map { pair in
                SettingsDiffRow.change(
                    census,
                    instance: pair.1.raw,
                    label: instanceLabel(base, pair.1.raw),
                    old: pair.0.raw,
                    new: pair.1.raw
                )
            }
    }

    /// Diff rows for space layout mode assignments
    /// (`SpacesSection.modeBinding`).
    private static func spacesModeRows(
        _ census: SettingKey,
        old: GuiConfig,
        new: GuiConfig
    ) -> [SettingsDiffRow] {
        let base = L("diff.label.space_mode", "Layout mode")
        let touched = Set(old.spaceModes.keys)
            .union(new.spaceModes.keys)
            .filter {
                (old.spaceModes[$0] ?? .bsp)
                    != (new.spaceModes[$0] ?? .bsp)
            }
            .sorted { $0.raw < $1.raw }
        return touched.map { space in
            SettingsDiffRow.change(
                census,
                instance: space.raw,
                label: instanceLabel(base, space.raw),
                old: (old.spaceModes[space] ?? .bsp).displayName,
                new: (new.spaceModes[space] ?? .bsp).displayName
            )
        }
    }

    /// Diff rows for space icon assignments (#68).
    private static func spacesIconRows(
        _ census: SettingKey,
        old: GuiConfig,
        new: GuiConfig
    ) -> [SettingsDiffRow] {
        let base = L("diff.label.space_icon", "Space icon")
        let o = old.settings.spaceIcons
        let n = new.settings.spaceIcons
        let touched = Set(o.keys).union(n.keys)
            .filter { o[$0] != n[$0] }
            .sorted { $0.raw < $1.raw }
        return touched.map { space in
            SettingsDiffRow.change(
                census,
                instance: space.raw,
                label: instanceLabel(base, space.raw),
                old: o[space] ?? unset,
                new: n[space] ?? unset
            )
        }
    }
}
