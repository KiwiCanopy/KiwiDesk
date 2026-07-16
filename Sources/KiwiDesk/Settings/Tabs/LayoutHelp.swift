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

    /// The two #222 arrangement pickers, shared by the Stack
    /// tab and the per-space Customize rows like the trio above.
    @MainActor static var stackPosition: String {
        L(
            "layout_params.stack_position.help",
            "Which side of the screen the stack zone takes; "
                + "the master zone gets the other side. The "
                + "stack lines up to fit its strip: a left or "
                + "right stack runs top to bottom, a top or "
                + "bottom stack side by side."
        )
    }

    @MainActor static var masterOrientation: String {
        L(
            "layout_params.master_orientation.help",
            "How the master zone lines up its windows when "
                + "the master count is more than one: stacked "
                + "top to bottom, or side by side."
        )
    }

    /// Wrap-focus, shared by all three array-order layouts
    /// (Scrolling, Track, Monocle) — one string since they now
    /// share the default (off, #257).
    ///
    /// Key deviates from the usual `<label-key>.help` derivation:
    /// the wrap-focus *label* is itself split across pre-existing
    /// keys (`scroll_grid.wrap_focus` for Scrolling/Monocle,
    /// `track.wrap_focus` for Track, from #168), so no single
    /// label key yields one help key. It lives under a neutral
    /// `layout_params.wrap_focus.help` home instead — unlike
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

    /// Scrolling's per-space slot-size override (#290). Names the
    /// orientation-driven meaning (column width vs row height) and
    /// the two auto standards so the checkbox's inherited value
    /// reads clearly.
    @MainActor static var slotSize: String {
        L(
            "space_override.slot_size.help",
            "Sets each scrolling window's size along the scroll "
                + "direction. Horizontal uses column width; "
                + "vertical uses row height. Default is 1100 pt "
                + "horizontally and 80% of the available height "
                + "vertically."
        )
    }

    /// Scrolling's focus-shift animation toggle (#290). Its
    /// static schematic can't demonstrate motion, so the help
    /// carries the behavior and points at how Scroll speed relates.
    @MainActor static var animateFocusShifts: String {
        L(
            "scroll_grid.animate_focus_shifts.help",
            "Moves windows smoothly when focus changes in a "
                + "Scrolling space. Turn this off to move the "
                + "layout immediately. Scroll speed sets how long "
                + "the movement takes and has no effect while "
                + "animation is off."
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
