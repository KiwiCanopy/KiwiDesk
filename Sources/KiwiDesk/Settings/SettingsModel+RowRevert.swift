import KiwiDeskCore

/// Per-row revert in the draft diff rows (#792): a row's ↺ takes
/// its one change back to the baseline, through the census key's
/// writer or the row's own way back (`SettingsRowRevert`).
extension SettingsModel {
    /// Whether `row` has a way back for its ↺.
    func canRevert(_ row: SettingsDiffRow) -> Bool {
        switch row.revert {
        case .census: SettingsRevertRegister.writers[row.key] != nil
        case .lua, .look, .lookChanges, .ruleReach, .binding,
            .layerMembers, .lensFields, .lensReach:
            true
        case .layer(let stored, let page):
            !layerRevertBlocked(stored: stored, page: page)
        case .lens(let stored, let page):
            !lensRevertBlocked(stored: stored, page: page)
        case .live: target == .live && !row.keepIDs.isEmpty
        case .none, .unstated: false
        }
    }

    /// Whether `row`'s ↺ takes more than its own row — a whole
    /// layer or lens, or every shortcut change — and so asks first.
    func revertTakesGroup(_ row: SettingsDiffRow) -> Bool {
        switch row.revert {
        case .census:
            SettingsRevertRegister.writers[row.key]?.takesGroup == true
        case .layer, .lens: true
        default: false
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
        case .lookChanges:
            SettingsDiffRowSource.lookMembers(of: self).forEach(revert)
        case .ruleReach(let app):
            revertRuleReach(of: row.key, app: app)
        case .live:
            revertLive(row.keepIDs)
        case .binding(let layer, let lua):
            revertBinding(layer: layer, lua: lua)
        case .layer(let stored, let page):
            revertLayer(stored: stored, page: page)
        case .layerMembers(let page, let profile):
            revertLayerMembers(page: page, profile: profile)
        case .lens(let stored, let page):
            revertLens(stored: stored, page: page)
        case .lensFields(let page):
            revertLensFields(page: page)
        case .lensReach(let page, let profile):
            revertLensReach(page: page, profile: profile)
        case .none, .unstated:
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
        case .shortcuts(.layers):
            // A shortcut's reach row: the binding and its reach.
            let parts = RuleReachTable<String>.keyParts(app)
            revertBinding(layer: parts.layer, lua: parts.lua)
        default:
            break
        }
    }
}
