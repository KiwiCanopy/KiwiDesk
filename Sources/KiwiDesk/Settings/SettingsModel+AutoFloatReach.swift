import KiwiDeskCore

/// The Automatic floating card's checklists (#2173).
extension SettingsModel {
    /// The checklist of a Tile-list row (#2173).
    func tileReach(_ app: String) -> RuleReachReading? {
        guard let reach = encodedReach else { return nil }
        return reading(
            reach.tileRules,
            app.lowercased(),
            reach.unreadable,
            picked: reachEdits.reach[.tile]?[app.lowercased()]
        ) { _ in AutoFloatWords.tiles }
    }

    /// The "Float windows automatically" switch's checklist (#2173).
    func autoFloatReach() -> RuleReachReading? {
        guard let reach = encodedReach else { return nil }
        let key = RuleReachTable<Bool>.floatAutomaticallyKey
        return reading(
            reach.floatAutomatically,
            key,
            reach.unreadable,
            picked: reachEdits.reach[.autoFloat]?[key],
            AutoFloatWords.value
        )
    }
}
