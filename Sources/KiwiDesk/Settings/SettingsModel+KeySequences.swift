import KiwiDeskCore

extension SettingsModel {
    /// A leader re-recorded from `old` to `new` in `layer` keeps the
    /// sequence's "Applies to" (#3124 ▸ Ruling 2): the key table keys a
    /// sequence by its leader, so the reach moves to the new key.
    func carrySequenceReach(
        layer: String,
        from old: String,
        to new: String
    ) {
        guard !old.isEmpty, !new.isEmpty, old != new else { return }
        carryPick(
            .key,
            from: RuleReachTable<String>.sequenceID(layer: layer, leader: old),
            to: RuleReachTable<String>.sequenceID(layer: layer, leader: new)
        )
    }
}

extension SettingsModel {
    /// The groups bindings make of their own (#2544): the installed
    /// ones in KiwiHub's order, then any only this draft names — a
    /// sequence's end keys included (#3162). The group field's menu
    /// on the Lua rows and in the Key sequences card alike.
    func shortcutGroupsInUse() -> [String] {
        ShortcutGroup.custom(
            in: core.customShortcutGroups()
                + config.layers.flatMap(\.actionBindings).map(\.group)
        )
    }
}
