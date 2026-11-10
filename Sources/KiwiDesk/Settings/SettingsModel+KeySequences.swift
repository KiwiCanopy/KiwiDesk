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
