import KiwiDeskCore
import SwiftUI

/// Caption and accessibility text for Scrolling schematic preview (#753).
extension ScrollingSchematic {
    var caption: String {
        switch anchor {
        case .follow:
            return oneLine(
                L(
                    "layout.schematic.scrolling.caption_follow",
                    "%1$@ pins the focused window nowhere: the "
                        + "row pans the minimum needed to reveal "
                        + "it, so the side you came from stays in "
                        + "view. %2$@",
                    followName,
                    insertionClause
                )
            )
        case .center, .start, .end:
            return oneLine(
                L(
                    "layout.schematic.scrolling.caption_anchored",
                    "The focused window rests at the anchor and "
                        + "the row scrolls past it. %1$@",
                    insertionClause
                )
            )
        }
    }

    var axLabel: String {
        switch anchor {
        case .follow:
            return L(
                "layout.schematic.scrolling.ax_follow",
                "Scrolling preview: a row of windows moving "
                    + "through the screen frame; %1$@ pans the "
                    + "row the minimum needed to reveal the "
                    + "focused window, keeping the side you came "
                    + "from in view.",
                followName
            )
        case .center, .start, .end:
            return L(
                "layout.schematic.scrolling.ax_anchored",
                "Scrolling preview: a row of windows moving "
                    + "through the screen frame; the focused "
                    + "window rests at the anchor and the row "
                    + "scrolls past it."
            )
        }
    }

    /// Insertion point caption clause when insertion marker is drawn.
    var insertionClause: String {
        guard drawsInsertionMark else { return "" }
        return L(
            "layout.schematic.scrolling.insertion",
            "The + marks where the next window opens."
        )
    }

    /// Whether next-window insertion '+' marker is on canvas
    /// (`LayoutSchematicCaptionTests`).
    var drawsInsertionMark: Bool {
        hasMargin && abs(row.incoming) <= 1
    }

    private var followName: String {
        L("scroll_grid.anchor.follow", "Follow")
    }

    /// Trims trailing whitespace when optional insertion clause is omitted
    /// (`WITHHELD_ARGUMENTS`).
    private func oneLine(_ sentence: String) -> String {
        sentence.trimmingCharacters(in: .whitespaces)
    }
}
