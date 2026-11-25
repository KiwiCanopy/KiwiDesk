import KiwiDeskCore

/// A gesture card's title `?`: what its rows bind and how.
extension GestureListCard {
    var help: String {
        switch device {
        case .mouse:
            L(
                "shortcuts.gestures.list.mouse_help",
                "Bind a drag, a move, a click, the wheel click, the "
                    + "side buttons or a scroll to an action. A click "
                    + "always takes keys held with it, so a plain click "
                    + "stays the app's; the wheel click and the side "
                    + "buttons may take none. With one action for every "
                    + "direction, a scroll steps as far as you scroll; "
                    + "give one direction its own action and each "
                    + "direction acts once per scroll instead. Where a "
                    + "mouse's own app, such as Logi Options+, remaps a "
                    + "button, KiwiDesk sees what that app sends."
            )
        case .trackpad:
            // The ladder is stated here once, for swipes (#1873 ▸
            // Ruling 2026-11-15).
            L(
                "shortcuts.gestures.list.trackpad_help_steps",
                "Bind a tap, a swipe, a pinch or a rotation to an "
                    + "action; a tap may take no keys. Two fingers move "
                    + "between windows, three between Spaces and the "
                    + "Desktop overview, four between screens. A "
                    + "two-finger swipe that moves between windows can "
                    + "step as far as you swipe; every other swipe takes "
                    + "one step. Give one direction its own action and "
                    + "it acts once per swipe."
            )
        }
    }
}
