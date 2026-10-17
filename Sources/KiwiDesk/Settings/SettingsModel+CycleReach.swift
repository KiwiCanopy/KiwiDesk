import KiwiDeskCore

extension SettingsModel {
    /// The layout cycle row's checklist (#453).
    func cycleReach() -> RuleReachReading? {
        guard let reach = encodedReach else { return nil }
        let key = RuleReachTable<[LayoutMode]>.modeCycleKey
        return reading(
            reach.modeCycle,
            key,
            reach.unreadable,
            picked: reachEdits.reach[.cycle]?[key],
            LayoutCycleWords.readout
        )
    }
}
