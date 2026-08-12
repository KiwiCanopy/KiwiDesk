import KiwiDeskCore

/// Spaces rows: the space list itself, the per-space
/// assignments (mode, icon), the fallback designation, and the
/// three action keys — which name no model path, so the draft
/// diff never attributes a change to them.
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
            // Actions: "(action)" ids are skipped by
            // `SettingsDraftDiff.censusBases()`, so no change
            // ever resolves to them — nothing to narrate.
            return []
        }
    }

    /// The list's own story is structural: one Added/Removed
    /// note per space that joined or left, and one Edited note
    /// for a pure reorder (same members, new order) — a scalar
    /// pair cannot state a permutation.
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

    /// A rename keeps the count and the position
    /// (`GuiConfig.renameSpace` maps in place), so the pairs
    /// read positionally: old name → new name. Adds and removes
    /// are `spaceList`'s story, so a count change leaves nothing
    /// for this key to say.
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

    /// Absent means the default `bsp` (the writer strips it —
    /// `SpacesSection.modeBinding`), so both sides resolve
    /// before comparing and a row always narrates two mode
    /// names, never a bare unset.
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

    /// The icon is its own display (an SF Symbol name, an emoji
    /// or a single character — #68's grammar), so the value is
    /// shown verbatim; a cleared entry reads as unset.
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
