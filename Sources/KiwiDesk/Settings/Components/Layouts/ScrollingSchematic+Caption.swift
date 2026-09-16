import KiwiDeskCore
import SwiftUI

/// Caption and accessibility text for Scrolling schematic preview (#753).
extension ScrollingSchematic {
    var caption: String {
        if lone { return loneCaption }
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
        case .center:
            return oneLine(centerCaption)
        case .start, .end:
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

    /// Center is the one anchor whose frame differs from the other
    /// two: a centred row meets both screen edges, and where the
    /// frame draws a window cut by one the caption says so — a key
    /// per sentence, the clause never pointing past the drawing
    /// (`LayoutSchematicCenterCaptionTests`).
    private var centerCaption: String {
        if drawsCutWindows {
            return L(
                "layout.schematic.scrolling.caption_center_cut",
                "The focused window rests in the middle and the "
                    + "row scrolls past it; the windows at the "
                    + "edges show only in part. %1$@",
                insertionClause
            )
        }
        return L(
            "layout.schematic.scrolling.caption_center",
            "The focused window rests in the middle and the row "
                + "scrolls past it. %1$@",
            insertionClause
        )
    }

    var axLabel: String {
        if lone { return loneAxLabel }
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
        case .center:
            return drawsCutWindows
                ? L(
                    "layout.schematic.scrolling.ax_center_cut",
                    "Scrolling preview: a row of windows moving "
                        + "through the screen frame; the focused "
                        + "window rests in the middle, the row "
                        + "scrolls past it, and the windows at the "
                        + "edges show only in part."
                )
                : L(
                    "layout.schematic.scrolling.ax_center",
                    "Scrolling preview: a row of windows moving "
                        + "through the screen frame; the focused "
                        + "window rests in the middle and the row "
                        + "scrolls past it."
                )
        case .start, .end:
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
        hasMargin && !lone && abs(row.incoming) <= 1
    }

    /// The lone-window sentence switches with the fill toggle
    /// (#1389) and, kept, with the anchor: a fixed anchor rests
    /// the one window where it says — at the edge, or centred,
    /// with the rest empty by design (#1388) — while `follow`
    /// leaves it where the row starts (`LayoutSchematicAloneTests`).
    /// The slot noun is a key per sentence, since a possessive
    /// agrees with it.
    private var loneCaption: String {
        if fillWhenAlone {
            return L(
                "layout.schematic.scrolling.caption_alone_fill",
                "One window fills the whole screen."
            )
        }
        switch (orientation, anchor) {
        case (.vertical, .follow):
            return L(
                "layout.schematic.scrolling.caption_alone_row",
                "One window keeps its row height and leaves the "
                    + "rest of the screen empty."
            )
        case (.vertical, _):
            return L(
                "layout.schematic.scrolling.caption_alone_row_at",
                "One window keeps its row height and rests at "
                    + "the anchor; the rest of the screen stays "
                    + "empty."
            )
        case (.horizontal, .follow):
            return L(
                "layout.schematic.scrolling.caption_alone_column",
                "One window keeps its column width and leaves the "
                    + "rest of the screen empty."
            )
        case (.horizontal, _):
            return L(
                "layout.schematic.scrolling.caption_alone_column_at",
                "One window keeps its column width and rests at "
                    + "the anchor; the rest of the screen stays "
                    + "empty."
            )
        }
    }

    private var loneAxLabel: String {
        if fillWhenAlone {
            return L(
                "layout.schematic.scrolling.ax_alone_fill",
                "Scrolling preview: one window filling the whole "
                    + "screen."
            )
        }
        switch (orientation, anchor) {
        case (.vertical, .follow):
            return L(
                "layout.schematic.scrolling.ax_alone_row",
                "Scrolling preview: one window at its row height, "
                    + "the rest of the screen empty."
            )
        case (.vertical, _):
            return L(
                "layout.schematic.scrolling.ax_alone_row_at",
                "Scrolling preview: one window at its row height "
                    + "resting at the anchor, the rest of the "
                    + "screen empty."
            )
        case (.horizontal, .follow):
            return L(
                "layout.schematic.scrolling.ax_alone_column",
                "Scrolling preview: one window at its column width, "
                    + "the rest of the screen empty."
            )
        case (.horizontal, _):
            return L(
                "layout.schematic.scrolling.ax_alone_column_at",
                "Scrolling preview: one window at its column "
                    + "width resting at the anchor, the rest of "
                    + "the screen empty."
            )
        }
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
