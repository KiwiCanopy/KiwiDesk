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
    /// this text would describe the wrong thing.
    @MainActor static var stackOverflow: String {
        L(
            "layout_params.overflow.help",
            "**Cascade overflow** — Keeps as many windows "
                + "fully tiled as fit, then cascades only the "
                + "extra ones at the bottom.\n**Cascade all** — "
                + "Cascades the whole stack, showing a sliver "
                + "of every window."
        )
    }
}
