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
        case .live: target == .live && !row.keepIDs.isEmpty
        case .none: false
        }
    }

    /// Whether `row`'s ↺ takes its whole group back — every shortcut
    /// change — and so asks first.
    func revertTakesGroup(_ row: SettingsDiffRow) -> Bool {
        row.revert == .census
            && SettingsRevertRegister.writers[row.key]?.takesGroup == true
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
        case .live:
            revertLive(row.keepIDs)
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
            SettingsRevertRegister.revertSubject(self, .space, app)
        case .appRules(.floatRules):
            SettingsRevertRegister.revertSubject(self, .float, app)
        default:
            break
        }
    }
}
