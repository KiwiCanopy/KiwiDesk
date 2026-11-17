import KiwiDeskCore

/// A Space rule's moves and removal (#3341, #3415). A moved rule
/// keeps its reach: a pattern edit, or a titled row turned bare, is
/// the same rule to every profile it reached, never a removal plus
/// a new rule at the default reach.
extension SettingsModel {
    /// Moves `old`'s rule to `new` in the draft through `edit`, its
    /// reach carried by the one `carryPick`; an edit that changes
    /// nothing records nothing.
    func moveSpaceRule(
        from old: SpaceRuleRow,
        to new: SpaceRuleRow,
        _ edit: (inout GuiConfig) -> Void
    ) {
        var moved = config
        edit(&moved)
        guard moved != config else { return }
        carryPick(
            Self.family(of: old),
            from: old.key,
            to: new.key,
            in: Self.family(of: new)
        )
        config = moved
    }

    /// The trash on a Space row: `removal` recorded for its family,
    /// then its rule dropped from the draft (#3415).
    func removeSpaceRule(_ row: SpaceRuleRow, _ removal: RuleRemoval) {
        recordRemoval(Self.family(of: row), row.key, removal)
        SpaceRuleEdit.drop(row, from: &config)
    }

    static func family(of row: SpaceRuleRow) -> RuleFamily {
        row.fragment == nil ? .space : .titledSpace
    }
}
