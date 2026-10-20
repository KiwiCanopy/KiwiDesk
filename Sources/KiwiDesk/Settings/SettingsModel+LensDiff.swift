import KiwiDeskCore

/// The save pill's rows for the lens page's draft (#2103): a lens
/// added, deleted, renamed or edited, and each saved profile it
/// newly reaches or leaves out. Every reason the pill counts owes a
/// row here (gui.md ▸ the save pill).
extension SettingsModel {
    func lensDiffRows() -> [SettingsDiffRow] {
        guard let edits = reachEdits.lenses else { return [] }
        let stored = core.kiwiVisionStoredLenses
        var result: [SettingsDiffRow] = []
        for name in edits.deleted {
            result.append(
                row(
                    name,
                    "deleted",
                    L("kiwivision.lens.diff.deleted", "deleted"),
                    .lens(stored: name, page: nil)
                )
            )
        }
        for draft in edits.lenses {
            let name = draft.lens.name
            guard let old = draft.stored,
                let before = stored.first(where: { $0.name == old })
            else {
                result.append(
                    row(
                        name,
                        "new",
                        L("kiwivision.lens.diff.new", "added"),
                        .lens(stored: nil, page: name)
                    )
                )
                result += reachRows(name)
                continue
            }
            if old != name {
                result.append(
                    row(
                        old,
                        "renamed",
                        L(
                            "kiwivision.lens.diff.renamed",
                            "renamed to “%1$@”",
                            name
                        ),
                        .lens(stored: old, page: name)
                    )
                )
            }
            var after = draft.lens
            after.name = before.name
            if after != before {
                result.append(
                    row(
                        name,
                        "edited",
                        L("kiwivision.lens.diff.edited", "edited"),
                        .lensFields(page: name)
                    )
                )
            }
            result += reachRows(name)
        }
        return result
    }

    /// One row per saved profile `name` newly reaches or leaves out;
    /// a new lens starts out reaching every one.
    private func reachRows(_ name: String) -> [SettingsDiffRow] {
        guard let after = lensReach(name), let profiles = lensProfiles,
            let before = lensReachWithoutPick(name)
        else { return [] }
        return profiles.compactMap { profile in
            let had = before.contains(profile)
            let has = after.contains(profile)
            guard had != has else { return nil }
            return row(
                name,
                "reach.\(profile)",
                has
                    ? L(
                        "kiwivision.lens.diff.added_to",
                        "added to %1$@",
                        profile
                    )
                    : L(
                        "kiwivision.lens.diff.left_out",
                        "left out of %1$@",
                        profile
                    ),
                .lensReach(page: name, profile: profile)
            )
        }
    }

    private func row(
        _ lens: String,
        _ instance: String,
        _ note: String,
        _ revert: SettingsRowRevert
    ) -> SettingsDiffRow {
        var row = SettingsDiffRow.note(
            .kiwiVision(.lenses),
            instance: "lens.\(lens).\(instance)",
            label: L("kiwivision.lens.diff.label", "“%1$@” lens", lens),
            note: note
        )
        row.revert = revert
        return row
    }
}
