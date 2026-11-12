import KiwiDeskCore

/// Which profiles a gesture binding reaches (#3225). A re-keyed row
/// carries its reach through `carryPick`, as a sequence does.
extension SettingsModel {
    /// The checklist of a gesture row, keyed by
    /// `GestureKey.spelling`; nil without a checklist.
    func gestureReach(_ key: String) -> RuleReachReading? {
        guard let reach = encodedReach else { return nil }
        return reading(
            reach.gestures,
            key,
            reach.unreadable,
            picked: reachEdits.reach[.gesture]?[key]
        ) { GestureListWords.value($0) }
    }
}
