import KiwiDeskCore

/// The save pill's rows for what a checklist reached (#1393):
/// every OTHER profile whose rule changes, read by comparing what
/// it resolves before and after, and the shared rule appearing or
/// leaving. The edited profile's own change is already a config
/// row (`SettingsValueReadout`).
extension SettingsModel {
    func reachDiffRows() -> [SettingsDiffRow] {
        // The layered snapshot is what the row edits encoded against:
        // a layer edit is the layer rows' (#2022), never a row's.
        // The lenses are app-wide and need no page (#2103).
        // A lens or layer edit has no one-row way back yet (#792).
        let lenses = lensDiffRows()
        guard let stored = layeredReach, let encoded = encodedReach,
            let editing = reachProfile
        else { return lenses }
        return layerDiffRows() + lenses
            + rows(
                .appRules(.appRules),
                .space,
                stored.appRules,
                encoded.appRules,
                editing: editing
            ) { $0.raw }
            + rows(
                .appRules(.floatRules),
                .float,
                stored.floatRules,
                encoded.floatRules,
                editing: editing,
                describe: Self.floatWords
            )
            + rows(
                .shortcuts(.layers),
                .key,
                stored.keyLayers,
                encoded.keyLayers,
                editing: editing,
                revertable: false,
                name: { key in
                    encoded.keyTemplates[key].map {
                        KeybindingCatalog.localizedName(
                            of: $0,
                            config: config
                        )
                    } ?? RuleReachTable<String>.keyParts(key).lua
                },
                describe: { ShortcutsReferenceBuilder.glyphs($0) }
            )
    }

    /// A float rule set in the Float menu's own words.
    static func floatWords(_ rules: [String]) -> String {
        rules.contains { !FloatFacet.isTitled($0) }
            ? L("app_rules.float.scope.all", "All windows")
            : L("app_rules.float.scope.titled.resting", "Windows titled")
    }

    private func rows<V>(
        _ key: SettingKey,
        _ family: RuleFamily,
        _ stored: RuleReachTable<V>,
        _ encoded: RuleReachTable<V>,
        editing: String,
        revertable: Bool = true,
        name: (String) -> String = {
            KeybindingCatalog.displayName(forBundleID: $0)
        },
        describe: (V) -> String
    ) -> [SettingsDiffRow] {
        let apps = Set(encoded.touched.values.flatMap { $0 })
            .union(encoded.baseTouched)
        let loaded = reachLoaded
        let none = L("app_rules.reach.diff.none", "No rule")
        var result: [SettingsDiffRow] = []
        for app in apps.sorted() {
            let name = name(app)
            let subject = ReachSubject(family: family, key: app)
            let own = (
                old: stored.resolved(app, for: editing),
                new: encoded.resolved(app, for: editing)
            )
            var appRows: [SettingsDiffRow] = []
            // Profiles that changed alike are one row (owner
            // 2026-10-18); the loaded one keeps its own, since it
            // applies at once.
            var groups: [(old: V?, new: V?, profiles: [String])] = []
            for profile in encoded.profiles where profile != editing {
                let old = stored.resolved(app, for: profile)
                let new = encoded.resolved(app, for: profile)
                guard old != new else { continue }
                guard profile != loaded else {
                    appRows.append(
                        .change(
                            key,
                            instance: "reach.\(profile).\(app)",
                            label: loadedLabel(profile, name),
                            old: old.map(describe) ?? none,
                            new: new.map(describe) ?? none
                        )
                    )
                    continue
                }
                if let at = groups.firstIndex(where: {
                    $0.old == old && $0.new == new
                }) {
                    groups[at].profiles.append(profile)
                } else {
                    groups.append((old, new, [profile]))
                }
            }
            let largestFirst = groups.enumerated().sorted {
                ($1.element.profiles.count, $0.offset)
                    < ($0.element.profiles.count, $1.offset)
            }
            for (_, group) in largestFirst {
                var row = SettingsDiffRow.change(
                    key,
                    instance: "reach.\(group.profiles[0]).\(app)",
                    label: L(
                        "app_rules.reach.diff.group",
                        "%1$@ · %2$@",
                        name,
                        RuleReachWords.group(group.profiles)
                    ),
                    old: group.old.map(describe) ?? none,
                    new: group.new.map(describe) ?? none
                )
                row.subject = subject
                if own.old != own.new, group.old == own.old,
                    group.new == own.new
                {
                    row.foldReach = foldWords(
                        [editing] + group.profiles,
                        of: encoded.profiles
                    )
                }
                appRows.append(row)
            }
            let wasShared = stored.base[app] != nil
            let isShared = encoded.base[app] != nil
            if wasShared != isShared {
                appRows.append(
                    .note(
                        key,
                        instance: "reach.new.\(app)",
                        label: name,
                        note: isShared
                            ? L(
                                "app_rules.reach.diff.new_profiles_get",
                                "New profiles get this rule"
                            )
                            : L(
                                "app_rules.reach.diff.new_profiles_lose",
                                "New profiles won't get this rule"
                            )
                    )
                )
            }
            // The app's rule and its reach go back as one (#792).
            for var row in appRows {
                row.revert = revertable ? .ruleReach(app: app) : .none
                result.append(row)
            }
        }
        return result
    }

    private func loadedLabel(_ profile: String, _ app: String) -> String {
        L(
            "app_rules.reach.diff.label_loaded",
            "%1$@ (loaded, applies at once) · %2$@",
            profile,
            app
        )
    }

    /// The reach column's words for `profiles`, in the table's
    /// order — every profile, else the ladder past one.
    private func foldWords(
        _ profiles: [String],
        of all: [String]
    ) -> String {
        let reached = all.filter(profiles.contains)
        return reached.count == all.count
            ? RuleReachWords.allProfiles
            : RuleReachWords.group(reached)
    }
}
