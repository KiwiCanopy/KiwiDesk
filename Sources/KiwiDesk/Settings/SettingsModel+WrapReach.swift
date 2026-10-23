import KiwiDeskCore

extension SettingsModel {
    /// The Wrap focus row's checklist (#2493).
    func wrapReach() -> RuleReachReading? {
        guard let reach = encodedReach else { return nil }
        let key = RuleReachTable<FocusWrap>.focusWrapKey
        return reading(
            reach.focusWrap,
            key,
            reach.unreadable,
            picked: reachEdits.reach[.wrap]?[key],
            FocusWrapWords.value
        )
    }
}
