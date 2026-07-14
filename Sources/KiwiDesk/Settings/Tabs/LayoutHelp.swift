import KiwiDeskCore

/// Shared #94 help copy for layout fields rendered on two
/// surfaces — a mode's Layout Defaults tab and the per-space
/// Customize popover — so both read one authored string
/// (`extract-keys` fails loudly on same-key English drift, but
/// one authoring point beats two to begin with). Computed, not
/// stored, so a GUI language switch re-reads the catalog.
enum LayoutHelp {
    @MainActor static var splitStrategy: String {
        L(
            "layout_params.split_strategy.help",
            "**Longest side** — Cuts whichever side of the "
                + "region is longer, keeping new windows close "
                + "to square.\n**Alternating** — Alternates "
                + "left/right and top/bottom cuts as the layout "
                + "gets deeper, regardless of shape."
        )
    }

    @MainActor static var splitRatioH: String {
        L(
            "layout_params.split_ratio_h.help",
            "How much of a side-by-side split's width goes to "
                + "the earlier window; the later window gets "
                + "the rest. Applies to every left/right split."
        )
    }

    @MainActor static var splitRatioV: String {
        L(
            "layout_params.split_ratio_v.help",
            "How much of a stacked split's height goes to the "
                + "earlier window; the later window gets the "
                + "rest. Applies to every top/bottom split."
        )
    }

    /// Stack's overflow styles. Deliberately NOT reused by
    /// Track's same-named picker: there the enum governs only
    /// the far-edge overflow track (and the default flips), so
    /// this text would describe the wrong thing — hence the
    /// stack-scoped key under the shared label key. Track's
    /// own text is on the #94 audit follow-up list.
    @MainActor static var stackOverflow: String {
        L(
            "layout_params.overflow.stack.help",
            "**Cascade overflow** — Keeps as many windows "
                + "fully tiled as fit, then cascades only the "
                + "extra ones at the bottom.\n**Cascade all** — "
                + "Cascades the whole stack, showing a sliver "
                + "of every window."
        )
    }

    /// `PlacementPicker`'s default text — every layout tab
    /// inherits it with the component. Track overrides it
    /// (below); hoisted here so no `+`-chain sits inside a
    /// `body` expression (§5 type-checker budget).
    @MainActor static var newWindowPlacement: String {
        L(
            "placement.new_window.help",
            "Where a new window lands relative to the others: "
                + "First or Last in the layout's order, or "
                + "right before or after whichever window is "
                + "focused at the moment it opens."
        )
    }

    /// Track's Position picker shares `PlacementPicker` but
    /// places a whole track in own-track mode, so the
    /// window-centric default above would be wrong there.
    @MainActor static var trackPosition: String {
        L(
            "track.new_window_position.help",
            "With \u{201C}Opens own track\u{201D}, where the "
                + "new track lands among the tracks; with "
                + "\u{201C}Joins the focused track\u{201D}, "
                + "where the window lands inside it: First, "
                + "Last, or right before or after the focused "
                + "one."
        )
    }
}
