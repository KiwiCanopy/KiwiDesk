import KiwiDeskCore

/// Which profiles a gesture binding reaches (#3225): the gesture
/// family's checklist and the reach a re-keyed row carries along.
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

    /// A row moved from `old` to `new` keeps the reach it had: the
    /// new key takes it, and the old key leaves where it reached —
    /// every holder of a shared row, the edited profile alone for
    /// a listed one. Called before the draft's map moves.
    func moveGestureReach(from old: GestureKey, to new: GestureKey) {
        guard old != new,
            let reach = reachEdits.reach[.gesture]?[old.spelling]
                ?? storedDefault(.gesture, old.spelling)
        else { return }
        reachEdits.reach[.gesture, default: [:]][new.spelling] = reach
        reachEdits.reach[.gesture]?[old.spelling] = nil
        recordRemoval(
            .gesture,
            old.spelling,
            reach.isShared ? .everywhere : .here
        )
    }
}
