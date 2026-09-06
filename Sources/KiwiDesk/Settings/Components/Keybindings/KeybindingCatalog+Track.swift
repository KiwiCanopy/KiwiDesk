import KiwiDeskCore

/// Track shortcut rows (#185, #128, #182, #188).
///
/// Written out per row rather than mapped over a step table:
/// each label is a whole sentence (#1110) whose key must be a
/// literal for `scripts/extract-keys` to see it.
extension KeybindingCatalog {
    /// Move window to previous/next track rows (#185, #128).
    static let moveToTrackRows: [NavCommand] = [
        NavCommand(
            label: "Move window to previous track",
            lua: "KiwiDesk.move_to_track(\"prev\")",
            displayLabel: {
                L(
                    "keybinding.move_window_to_prev_track",
                    "Move window to previous track"
                )
            }
        ),
        NavCommand(
            label: "Move window to next track",
            lua: "KiwiDesk.move_to_track(\"next\")",
            displayLabel: {
                L(
                    "keybinding.move_window_to_next_track",
                    "Move window to next track"
                )
            }
        ),
    ]

    /// Swap with previous/next track rows (#182, #188).
    static let trackSwapRows: [NavCommand] = [
        NavCommand(
            label: "Swap with previous track",
            lua: "track.swap(\"prev\")",
            displayLabel: {
                L(
                    "keybinding.swap_with_prev_track",
                    "Swap with previous track"
                )
            }
        ),
        NavCommand(
            label: "Swap with next track",
            lua: "track.swap(\"next\")",
            displayLabel: {
                L(
                    "keybinding.swap_with_next_track",
                    "Swap with next track"
                )
            }
        ),
    ]
}
