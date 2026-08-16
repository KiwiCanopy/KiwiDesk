import KiwiDeskCore
import SwiftUI

/// `TrackSchematic`'s words — the caption under the frame and the
/// label VoiceOver reads instead of it. Split out at the §2.1
/// ceiling when the preview learned fill-then-spill (#708), on the
/// `ScrollingSchematic+Caption` precedent: the drawing and the
/// sentence beside it fail apart, so they are guarded apart
/// (`LayoutSchematicCaptionTests`).
extension TrackSchematic {
    /// The rule the frame cannot denote, in words — and **only
    /// the clauses the frame actually draws** (#708).
    ///
    /// The overflow clause used to be welded into both captions,
    /// so the preview named a far-edge track that the strip draws
    /// only when something overflows. At the shipped defaults —
    /// `auto_tracks` on, five windows — nothing does, so the
    /// caption asserted a track that was not on the frame and
    /// VoiceOver asserted it again. That is the same class as
    /// Scrolling's insertion `+`, which `drawsInsertionMark`
    /// already conditions; `LayoutSchematicCaptionTests` holds
    /// both.
    ///
    /// Two keys per arm rather than one with a `%@` hole: the
    /// clause is a whole sentence in some locales and a trailing
    /// subordinate in others, and a frame with an argument the
    /// GUI may render EMPTY has to register in
    /// `WITHHELD_ARGUMENTS` — a heavier contract than two plain
    /// sentences, for prose that never interpolates a value.
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

    /// Same conditionality as the caption: a spoken label may no
    /// more assert an undrawn track than a written one may.
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
