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

    /// Wrap-focus for the linear layouts (Scrolling, Track),
    /// where it defaults off. Monocle shares the concept but
    /// flips the default, so it gets its own scoped text below.
    ///
    /// Key deviates from the usual `<label-key>.help` derivation:
    /// the wrap-focus *label* is itself split across pre-existing
    /// keys (`scroll_grid.wrap_focus` for Scrolling/Monocle,
    /// `track.wrap_focus` for Track, from #168), so no single
    /// label key yields one help key. These live under a neutral
    /// `layout_params.wrap_focus.*` home instead — unlike
    /// `trackOverflow`, whose label key `layout_params.overflow`
    /// does derive cleanly.
    @MainActor static var wrapFocus: String {
        L(
            "layout_params.wrap_focus.help",
            "When on, moving focus past the last window wraps "
                + "around to the first, and past the first back "
                + "to the last, instead of stopping at the end."
        )
    }

    /// Monocle's wrap-focus: same behaviour, but on by default
    /// (a carousel), so the text leads with that.
    @MainActor static var wrapFocusMonocle: String {
        L(
            "layout_params.wrap_focus.monocle.help",
            "On by default: monocle is a carousel, so moving "
                + "focus past the last window returns to the "
                + "first (and the reverse). Turn it off to stop "
                + "focus at the first and last window."
        )
    }

    /// Track's far-edge overflow track. Same enum as Stack's
    /// overflow but it governs only that one track and the
    /// default flips to Cascade all, so it can't reuse
    /// `stackOverflow` (see that property's note). The closing
    /// line clarifies that ordinary tracks overflow too — they
    /// are always `cascade_overflow` — and only this far-edge
    /// track is configurable.
    @MainActor static var trackOverflow: String {
        L(
            "layout_params.overflow.track.help",
            "How the far-edge **overflow track** — which "
                + "collects the tracks that don't fit side by "
                + "side — packs its windows.\n**Cascade all** "
                + "(the default) — piles every window from the "
                + "top.\n**Cascade overflow** — tiles what fits, "
                + "piles the rest.\nAn ordinary track that holds "
                + "more windows than fit always overflows this "
                + "second way; only the far-edge track is "
                + "configurable."
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
