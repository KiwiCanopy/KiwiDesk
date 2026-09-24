import KiwiDeskCore

/// The save pill's rows for what a checklist reached (#1393):
/// every OTHER profile whose rule changes, read by comparing what
/// it resolves before and after, and the shared rule appearing or
/// leaving. The edited profile's own change is already a config
/// row (`SettingsValueReadout`).
extension SettingsModel {
    func reachDiffRows() -> [SettingsDiffRow] {
        guard let stored = ruleReachStored, let encoded = encodedReach,
            let editing = reachProfile
        else { return [] }
        return rows(
            .appRules(.appRules),
            stored.appRules,
            encoded.appRules,
            editing: editing
        ) { $0.raw }
            + rows(
                .appRules(.floatRules),
                stored.floatRules,
                encoded.floatRules,
                editing: editing,
                describe: Self.floatWords
            )
    }

    /// A float rule set in the Float menu's own words.
    static func floatWords(_ rules: [String]) -> String {
        rules.contains { !$0.contains(":") }
            ? L("app_rules.float.scope.all", "All windows")
            : L("app_rules.float.scope.titled.resting", "Windows titled")
    }

    private func rows<V>(
        _ key: SettingKey,
        _ stored: RuleReachTable<V>,
        _ encoded: RuleReachTable<V>,
        editing: String,
        describe: (V) -> String
    ) -> [SettingsDiffRow] {
        let apps = Set(encoded.touched.values.flatMap { $0 })
            .union(encoded.baseTouched)
        let loaded = activeProfile
        let none = L("app_rules.reach.diff.none", "No rule")
        var result: [SettingsDiffRow] = []
        for app in apps.sorted() {
            let name = KeybindingCatalog.displayName(forBundleID: app)
            for profile in encoded.profiles where profile != editing {
                let old = stored.resolved(app, for: profile)
                let new = encoded.resolved(app, for: profile)
                guard old != new else { continue }
                result.append(
                    .change(
                        key,
                        instance: "reach.\(profile).\(app)",
                        label: label(profile, name, loaded: profile == loaded),
                        old: old.map(describe) ?? none,
                        new: new.map(describe) ?? none
                    )
                )
            }
            let wasShared = stored.base[app] != nil
            let isShared = encoded.base[app] != nil
            guard wasShared != isShared else { continue }
            result.append(
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
        return result
    }

    private func label(
        _ profile: String,
        _ app: String,
        loaded: Bool
    ) -> String {
        loaded
            ? L(
                "app_rules.reach.diff.label_loaded",
                "%1$@ (loaded, applies at once) · %2$@",
                profile,
                app
            )
            : L("app_rules.reach.diff.label", "%1$@ · %2$@", profile, app)
    }
}
