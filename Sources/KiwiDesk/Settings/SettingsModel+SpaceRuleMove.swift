import KiwiDeskCore

/// A Space rule moved to a new key keeps its reach (#3341): a
/// pattern edit, or a titled row turned bare, is the same rule to
/// every profile it reached, never a removal plus a new rule at the
/// default reach.
extension SettingsModel {
    /// Moves `old`'s rule to `new` in the draft through `edit`, and
    /// carries `old`'s reach — the draft's pick, else the stored one —
    /// onto `new`, its removal reaching the same profiles.
    func moveSpaceRule(
        from old: SpaceRuleRow,
        to new: SpaceRuleRow,
        _ edit: (inout GuiConfig) -> Void
    ) {
        let reach = reach(of: old)
        edit(&config)
        guard let reach else { return }
        let from = Self.family(of: old)
        let to = Self.family(of: new)
        reachEdits.reach[to, default: [:]][to.key(new.key)] = reach
        let alone =
            if case .listed(let profiles) = reach {
                profiles.count <= 1
            } else {
                false
            }
        recordRemoval(from, old.key, alone ? .here : .everywhere)
    }

    static func family(of row: SpaceRuleRow) -> RuleFamily {
        row.fragment == nil ? .space : .titledSpace
    }

    private func reach(of row: SpaceRuleRow) -> RuleReach? {
        let family = Self.family(of: row)
        let key = family.key(row.key)
        if let picked = reachEdits.reach[family]?[key] { return picked }
        guard let stored = layeredReach, let page = reachProfile else {
            return nil
        }
        let table =
            row.fragment == nil ? stored.appRules : stored.titledAppRules
        guard table.resolved(key, for: page) != nil else { return nil }
        return table.reach(of: key, editing: page)
    }
}
