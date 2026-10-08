import KiwiDeskCore

/// The save pill's rows for the draft's layer edits (#2022): a
/// layer deleted from every profile, renamed, left out of or added
/// to another profile, or entering or leaving the shared base. The
/// edited profile's own layer list is already a config row.
extension SettingsModel {
    func layerDiffRows() -> [SettingsDiffRow] {
        let edits = reachEdits
        guard !edits.layers.isEmpty || !edits.deletedLayers.isEmpty,
            let stored = ruleReachStored?.layerTable,
            let layered = layeredReach?.layerTable,
            let editing = reachProfile
        else { return [] }
        var result: [SettingsDiffRow] = []
        let deleted = edits.deletedLayers.sorted { $0.key < $1.key }
        for (name, removal) in deleted
        where removal == .everywhere && reachesOthers(name, stored, editing) {
            result.append(
                row(
                    name,
                    "deleted",
                    L(
                        "shortcuts.layer_reach.diff.deleted",
                        "deleted from every profile"
                    )
                )
            )
        }
        for (page, edit) in edits.layers.sorted(by: { $0.key < $1.key }) {
            guard let old = edit.stored else { continue }
            if old != page, reachesOthers(old, stored, editing) {
                result.append(
                    row(
                        old,
                        "renamed",
                        L(
                            "shortcuts.layer_reach.diff.renamed",
                            "renamed to “%1$@”",
                            page
                        )
                    )
                )
            }
            result += membershipRows(
                old,
                page,
                stored,
                layered,
                editing: editing
            )
        }
        return result
    }

    private func membershipRows(
        _ old: String,
        _ page: String,
        _ stored: RuleReachTable<Bool>,
        _ layered: RuleReachTable<Bool>,
        editing: String
    ) -> [SettingsDiffRow] {
        var result: [SettingsDiffRow] = []
        for profile in layered.profiles where profile != editing {
            let had = stored.resolved(old, for: profile) != nil
            let has = layered.resolved(page, for: profile) != nil
            guard had != has else { continue }
            result.append(
                row(
                    page,
                    "\(profile)",
                    has
                        ? L(
                            "shortcuts.layer_reach.diff.added",
                            "added to %1$@",
                            profile
                        )
                        : L(
                            "shortcuts.layer_reach.diff.left_out",
                            "left out of %1$@",
                            profile
                        )
                )
            )
        }
        let wasShared = stored.base[old] != nil
        let isShared = layered.base[page] != nil
        if wasShared != isShared {
            result.append(
                row(
                    page,
                    "new",
                    isShared
                        ? L(
                            "shortcuts.layer_reach.diff.new_profiles_get",
                            "new profiles get it"
                        )
                        : L(
                            "shortcuts.layer_reach.diff.new_profiles_lose",
                            "new profiles won't get it"
                        )
                )
            )
        }
        return result
    }

    /// Whether a change to stored layer `name` reaches past the
    /// edited profile's own file.
    private func reachesOthers(
        _ name: String,
        _ table: RuleReachTable<Bool>,
        _ editing: String
    ) -> Bool {
        table.base[name] != nil
            || table.profiles.contains {
                $0 != editing && table.resolved(name, for: $0) != nil
            }
    }

    private func row(
        _ layer: String,
        _ instance: String,
        _ note: String
    ) -> SettingsDiffRow {
        .note(
            .shortcuts(.layersReach),
            instance: "layer.\(layer).\(instance)",
            label: L(
                "shortcuts.layer_reach.diff.label",
                "“%1$@” layer",
                layer
            ),
            note: note
        )
    }
}
