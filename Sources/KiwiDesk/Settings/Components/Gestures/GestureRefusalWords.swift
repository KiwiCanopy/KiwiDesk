import KiwiDeskCore

/// Why a gesture row's keys or action are refused (#3199 ▸ Ruling):
/// Core names the refusal, the card words it under the row or in
/// the recorder, each as the rule that forbids it.
@MainActor
enum GestureRefusalWords {
    static func sentence(_ refusal: GestureRefusal) -> String {
        switch refusal {
        case .emptyAction:
            L("shortcuts.gestures.refusal.empty", "Choose an action.")
        case .needsModifier:
            L(
                "shortcuts.gestures.refusal.needs_key",
                "Hold at least one key with this gesture."
            )
        case .singleModifierScroll:
            L(
                "shortcuts.gestures.refusal.single_key",
                "Hold two or more keys: macOS and apps scroll with one."
            )
        case .shiftOnWheel:
            L(
                "shortcuts.gestures.refusal.shift",
                "macOS turns ⇧ and the wheel into a sideways scroll."
            )
        case .familyNotOffered:
            L(
                "shortcuts.gestures.refusal.family",
                "This gesture offers other actions; choose one of those."
            )
        case .directionalNeedsFamily:
            L(
                "shortcuts.gestures.refusal.directional",
                "A swipe or scroll takes one action for every direction, "
                    + "or one per direction."
            )
        case .grabOnlyOnDrag:
            L(
                "shortcuts.gestures.refusal.grab",
                "Only a drag or a move can hold a window."
            )
        case .noDirections:
            L(
                "shortcuts.gestures.refusal.no_directions",
                "This gesture has no directions."
            )
        case .keysHeldByDrag:
            L(
                "shortcuts.gestures.refusal.held_by_drag",
                "A drag already holds these keys."
            )
        }
    }

    /// A clash: another row of the card stands on these keys.
    static var taken: String {
        L(
            "shortcuts.gestures.refusal.taken",
            "Another row already holds these keys."
        )
    }
}
