import KiwiDeskCore
import SwiftUI

/// The Scrolling preview's words (#753).
///
/// **The caption and the a11y label switch on the anchor.** The
/// anchor is a picker the reader is operating, and one string
/// covering all four says nothing when they move it — worse, the
/// string that covered all four stated `follow`'s pan, so three
/// anchors carried a sentence about a fourth and VoiceOver
/// asserted it over a tile drawn with `center` selected. The
/// family already splits a caption wherever a control splits the
/// picture (`layout.schematic.monocle.caption_h` / `_v`,
/// `layout.schematic.stack.caption_all` / `_overflow`).
///
/// `center`, `start` and `end` share one frame of words on
/// purpose: what they change is *where* the focused window rests,
/// and the picture already shows that. `follow` rests where
/// `center` does — the two frames are pixel-identical, which is
/// the trade `docs/design-decisions.md` argues — so the caption is
/// the only place the difference can be stated at all.
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

    /// The `+` sentence — and only where the `+` is actually on
    /// the frame.
    ///
    /// The row is finite but several canvases wide at most counts,
    /// so the incoming slot is often clipped away entirely: with
    /// New window ▸ Last and the default five windows it already
    /// is, and First loses it the same way from about eight. A
    /// caption pointing at a mark that is not drawn is worse than
    /// no caption at all.
    var insertionClause: String {
        guard drawsInsertionMark else { return "" }
        return L(
            "layout.schematic.scrolling.insertion",
            "The + marks where the next window opens."
        )
    }

    /// Whether the `+` is on the frame — a condition on the ROW,
    /// deliberately, not on the pixels.
    ///
    /// The caption is drawn *beside* the frame and cannot read the
    /// `GeometryReader`'s width, so a pixel test here would be a
    /// model of the drawing rather than the drawing. A slot
    /// **adjacent to the focus** needs no width to answer: the
    /// focused tile sits wholly inside the monitor, one step is
    /// one slot plus 3 pt, and the monitor leaves
    /// `screenFraction`'s margin on the far side — so the
    /// neighbour reaches the canvas at every anchor, slot size and
    /// canvas length a panel can take.
    ///
    /// Only *sufficient*, on purpose: at a thin slot the `+` can
    /// be three slots out and still show, and the caption then
    /// says nothing about a mark that is drawn — which is what
    /// Stack's, Grid's and Monocle's captions do with theirs in
    /// every case. Silence under-labels; the alternative
    /// mislabels.
    ///
    /// Internal because `LayoutSchematicScrollingTests` holds the
    /// claim against the drawing's own `onCanvas`, over every
    /// anchor, placement, count and slot size at the widths a pane
    /// can take.
    var drawsInsertionMark: Bool { abs(row.incoming) <= 1 }

    /// Named with the picker's own term, so every locale reads its
    /// own translation of the segment rather than the English
    /// word sitting inside a translated sentence.
    private var followName: String {
        L("scroll_grid.anchor.follow", "Follow")
    }

    /// The frame carries the space before its optional clause, so
    /// a translator owns the spacing; with no clause to place, the
    /// space it left behind goes.
    private func oneLine(_ sentence: String) -> String {
        sentence.trimmingCharacters(in: .whitespaces)
    }
}
