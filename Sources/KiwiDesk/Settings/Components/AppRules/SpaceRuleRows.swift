import KiwiDeskCore

/// One row of the "Open in a Space" card (#3341): an app and, for a
/// titled rule, its fragment. `key` is the rule as its store keys it
/// — the bare app or `app:fragment` — and names the row for focus
/// return and `DeletionFocus`.
struct SpaceRuleRow: Hashable, Identifiable {
    let app: String
    let fragment: String?

    var key: String { AppTitleRule.rule(app: app, title: fragment) }
    var id: String { key }
}

/// The card's rows, grouped per app in the order the engine reads
/// them (`TitledSpaceRules.pick`): an app's titled rules in
/// `TitledSpaceRules.order(of:)`, its bare rule last.
enum SpaceRuleRows {
    /// Each app's rows, the apps in `apps`' order.
    static func groups(
        _ config: GuiConfig,
        apps: [String]
    ) -> [[SpaceRuleRow]] {
        let titled = TitledSpaceRules(config.titledAppRules)
        return apps.map { app in
            var rows = titled.order(of: app).map {
                SpaceRuleRow(app: app, fragment: $0.fragment)
            }
            if config.appRules[app] != nil {
                rows.append(SpaceRuleRow(app: app, fragment: nil))
            }
            return rows
        }
    }

    /// Every app with a Space rule, bare or titled.
    static func apps(_ config: GuiConfig) -> Set<String> {
        Set(config.appRules.keys).union(
            config.titledAppRules.keys.map(AppTitleRule.app(of:))
        )
    }

    /// Whether `row`'s app has rows besides it (#3415): what makes a
    /// bare row, or the bare row a titled one would become, "All
    /// other windows".
    static func othersBeside(
        _ row: SpaceRuleRow,
        in config: GuiConfig
    ) -> Bool {
        groups(config, apps: [row.app]).joined().contains { $0 != row }
    }

    /// The Space `row` opens its windows in.
    static func space(of row: SpaceRuleRow, in config: GuiConfig) -> SpaceID? {
        guard row.fragment != nil else { return config.appRules[row.app] }
        return config.titledAppRules[row.key]
    }
}

/// The card's writes that move a rule between its two stores
/// (#3341), each keeping the Space the rule had. A row's other write
/// is the pick of a Space; its removal is the section's trash.
enum SpaceRuleEdit {
    /// `row` rewritten to match `fragment`, keeping its Space: a
    /// bare row becomes a titled one, a titled one changes fragment.
    static func setFragment(
        _ fragment: String,
        of row: SpaceRuleRow,
        in config: inout GuiConfig
    ) {
        guard fragment != row.fragment,
            let space = SpaceRuleRows.space(of: row, in: config)
        else { return }
        drop(row, from: &config)
        let titled = SpaceRuleRow(app: row.app, fragment: fragment)
        config.titledAppRules[titled.key] = space
    }

    /// A new titled rule for `app`, in `space`.
    static func addTitled(
        _ fragment: String,
        for app: String,
        in space: SpaceID,
        config: inout GuiConfig
    ) {
        let row = SpaceRuleRow(app: app, fragment: fragment)
        config.titledAppRules[row.key] = space
    }

    /// Add Rule… off `row`: a titled rule in `row`'s Space, which
    /// the new row's own menu then moves. False when `row` has no
    /// Space to give it.
    @discardableResult
    static func addTitled(
        _ fragment: String,
        beside row: SpaceRuleRow,
        config: inout GuiConfig
    ) -> Bool {
        guard let space = SpaceRuleRows.space(of: row, in: config)
        else { return false }
        addTitled(fragment, for: row.app, in: space, config: &config)
        return true
    }

    /// A titled row turned to every window: it becomes the bare row,
    /// refused while the app has one (`allTaken`).
    static func makeBare(_ row: SpaceRuleRow, in config: inout GuiConfig) {
        guard row.fragment != nil, config.appRules[row.app] == nil,
            let space = SpaceRuleRows.space(of: row, in: config)
        else { return }
        drop(row, from: &config)
        config.appRules[row.app] = space
    }

    /// Whether `fragment` would repeat a titled row of `app`; the
    /// match is case-sensitive, so "work" is a rule of its own.
    static func repeats(
        _ fragment: String,
        app: String,
        except current: String?,
        in config: GuiConfig
    ) -> Bool {
        fragment != current
            && config.titledAppRules[
                SpaceRuleRow(app: app, fragment: fragment).key
            ] != nil
    }

    /// Removes `row`'s rule from its store.
    static func drop(_ row: SpaceRuleRow, from config: inout GuiConfig) {
        if row.fragment == nil {
            config.appRules.removeValue(forKey: row.app)
        } else {
            config.titledAppRules.removeValue(forKey: row.key)
        }
    }
}
