import KiwiDeskCore

/// Per-row revert in the draft diff rows (#792): a row's ↺ takes
/// its one change back to the baseline, through the census key's
/// writer or the row's own way back (`SettingsRowRevert`).
extension SettingsModel {
    /// Whether `row` has a way back for its ↺.
    func canRevert(_ row: SettingsDiffRow) -> Bool {
        switch row.revert {
        case .census: SettingsRevertRegister.writers[row.key] != nil
        case .lua, .look, .ruleReach: true
        case .none: false
        }
    }

    /// Takes `row`'s change back to the baseline.
    func revert(_ row: SettingsDiffRow) {
        switch row.revert {
        case .census:
            SettingsRevertRegister.writers[row.key]?.apply(
                self,
                row.instance
            )
        case .lua:
            luaSource = cleanLuaSource
        case .look(let profile):
            if let stored = lookReachStored[profile] {
                setLookFollows(profile, stored)
            } else {
                lookReachEdits[profile] = nil
            }
        case .ruleReach(let app):
            revertRuleReach(of: row.key, app: app)
        case .none:
            break
        }
    }

    /// One app's rule back to the baseline, with the reach the
    /// draft gave it (#1393): a reach row reports the rule's effect
    /// on another profile, so its way back is the rule's.
    private func revertRuleReach(of key: SettingKey, app: String) {
        switch key {
        case .appRules(.appRules):
            let mine = { (rule: (key: String, value: SpaceID)) in
                RuleFamily.space.key(rule.key) == app
            }
            var rules = config.appRules.filter { !mine($0) }
            for rule in cleanConfig.appRules where mine(rule) {
                rules[rule.key] = rule.value
            }
            config.appRules = rules
            clearReach(.space, app)
        case .appRules(.floatRules):
            let mine = { RuleFamily.float.key($0) == app }
            let at = config.floatRules.firstIndex(where: mine)
            var rules = config.floatRules.filter { !mine($0) }
            let back = cleanConfig.floatRules.filter(mine)
            let place = min(at ?? rules.count, rules.count)
            rules.insert(contentsOf: back, at: place)
            config.floatRules = rules
            clearReach(.float, app)
        default:
            break
        }
    }

    private func clearReach(_ family: RuleFamily, _ subject: String) {
        reachEdits.reach[family]?[subject] = nil
        reachEdits.removal[family]?[subject] = nil
    }
}
