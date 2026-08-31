import KiwiDeskCore
import SwiftUI

/// Localized caption and VoiceOver labels for Track layout schematic
/// (`LayoutSchematicCaptionTests`, #708).
extension TrackSchematic {
    /// Localized caption — only the clauses the frame actually
    /// draws (#708, `LayoutSchematicCaptionTests`). Two keys per
    /// arm rather than one with a `%@` hole: the clause is a whole
    /// sentence in some locales, and a frame whose argument the
    /// GUI may render EMPTY has to register in
    /// `WITHHELD_ARGUMENTS` — a heavier contract than two plain
    /// sentences.
    var caption: String {
        switch (newWindow, drawsOverflowTrack) {
        case (.ownTrack, true):
            return L(
                "layout.schematic.track.caption_own",
                "New windows open their own track; the far track "
                    + "piles the overflow."
            )
        case (.ownTrack, false):
            return L(
                "layout.schematic.track.caption_own_plain",
                "New windows open their own track."
            )
        case (.focusedTrack, true):
            return L(
                "layout.schematic.track.caption_focused",
                "New windows join the focused track until it is "
                    + "full, then open one beside it; the far "
                    + "track piles the overflow."
            )
        case (.focusedTrack, false):
            return L(
                "layout.schematic.track.caption_focused_plain",
                "New windows join the focused track until it is "
                    + "full, then open one beside it."
            )
        }
    }

    /// Spoken accessibility label matching rendered track schematic (#708).
    var axLabel: String {
        drawsOverflowTrack
            ? L(
                "layout.schematic.track.ax",
                "Track preview: tracks along one axis, the far "
                    + "one piling overflow; the plus is the next "
                    + "window."
            )
            : L(
                "layout.schematic.track.ax_plain",
                "Track preview: tracks along one axis; the plus "
                    + "is the next window."
            )
    }
}
