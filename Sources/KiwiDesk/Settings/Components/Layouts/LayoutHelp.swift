import KiwiDeskCore

/// Shared localized help text for layout settings across panels (#94).
enum LayoutHelp {
    @MainActor static var splitStrategy: String {
        L(
            "layout_params.split_strategy.help",
            "**%1$@** — Cuts whichever side of the "
                + "region is longer, keeping new windows close "
                + "to square.\n**%2$@** — Alternates "
                + "left/right and top/bottom cuts as the layout "
                + "gets deeper, regardless of shape.",
            L("layout_params.longest_side", "Longest side"),
            L("layout_params.alternating", "Alternating")
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

    /// Stack overflow styles help text (#94).
    @MainActor static var stackOverflow: String {
        L(
            "layout_params.overflow.stack.help",
            "**%1$@** — Keeps as many windows "
                + "fully tiled as fit, then cascades only the "
                + "extra ones at the bottom.\n**%2$@** — "
                + "Cascades the whole stack, showing a sliver "
                + "of every window.",
            L("layout_params.cascade_overflow", "Cascade overflow"),
            L("layout_params.cascade_all", "Cascade all")
        )
    }

    /// Stack zone position help text (#222).
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

    /// Master zone orientation help text (#222).
    @MainActor static var masterOrientation: String {
        L(
            "layout_params.master_orientation.help",
            "How the master zone lines up its windows when "
                + "the master count is more than one: stacked "
                + "top to bottom, or side by side."
        )
    }

    /// Wrap-focus behavior help text for array layouts (#257, #168).
    @MainActor static var wrapFocus: String {
        L(
            "layout_params.wrap_focus.help",
            "When on, moving focus past the last window wraps "
                + "around to the first, and past the first back "
                + "to the last, instead of stopping at the end."
        )
    }

    /// Monocle hide style help text (#881, #818).
    @MainActor static var monocleHideStyle: String {
        L(
            "monocle.hide_style.help",
            "**%1$@** — Hidden windows stay behind the focused "
                + "one, at full size.\n**%2$@** — Hidden "
                + "windows park in a corner instead, and focus "
                + "changes instantly. Choose this when the "
                + "windows behind show — through a transparent "
                + "window, or around one that can't fill the "
                + "whole screen. A thin edge of each parked "
                + "window stays visible in the corner.",
            L("monocle.hide_style.stack", "Stack behind"),
            L("monocle.hide_style.park", "Park in corner")
        )
    }

    /// Track far-edge overflow track help text.
    @MainActor static var trackOverflow: String {
        L(
            "layout_params.overflow.track.help",
            "How the far-edge **overflow track** — which "
                + "collects the tracks that don't fit side by "
                + "side — packs its windows.\n**%1$@** "
                + "(the default) — piles every window from the "
                + "top.\n**%2$@** — tiles what fits, "
                + "piles the rest.\nAn ordinary track that holds "
                + "more windows than fit always overflows this "
                + "second way; only the far-edge track is "
                + "configurable.",
            L("layout_params.cascade_all", "Cascade all"),
            L("layout_params.cascade_overflow", "Cascade overflow")
        )
    }

    /// Scrolling slot size override help text (#290, #818).
    @MainActor static var slotSize: String {
        L(
            "space_override.slot_size.help",
            "Sets each scrolling window's size along the scroll "
                + "direction — the column width when the "
                + "orientation is %1$@, the row height when it "
                + "is %2$@. As a unit, %3$@ scales with that "
                + "width or height (95%% out of the box) and "
                + "%4$@ fixes an exact size.",
            L("scroll_grid.horizontal", "Horizontal"),
            L("scroll_grid.vertical", "Vertical"),
            L("slot_size.percent", "Percent"),
            L("slot_size.points", "Points")
        )
    }

    /// Scrolling focus shift animation help text (#290).
    @MainActor static var animateFocusShifts: String {
        L(
            "scroll_grid.animate_focus_shifts.help",
            "Moves windows smoothly when focus changes in a "
                + "Scrolling Space. Turn this off to move the "
                + "layout immediately. %1$@ sets how long "
                + "the movement takes and has no effect while "
                + "animation is off.",
            L("scroll_grid.scroll_duration", "Scroll duration")
        )
    }

    /// Default new window placement help text (`PlacementPicker`,
    /// §5 type-checker budget).
    @MainActor static var newWindowPlacement: String {
        L(
            "placement.new_window.help",
            "Where a new window lands relative to the others: "
                + "First or Last in the layout's order, or "
                + "right before or after whichever window is "
                + "focused at the moment it opens."
        )
    }

    /// Track new window placement help text (#818).
    @MainActor static var trackPosition: String {
        L(
            "track.new_window_position.help",
            "With \u{201C}%1$@\u{201D}, where the new track "
                + "lands among the tracks; with "
                + "\u{201C}%2$@\u{201D}, where the window lands "
                + "inside that track: %3$@, %4$@, or right "
                + "before or after the focused window.",
            L("track.new_window.own", "Opens its own track"),
            L(
                "track.new_window.focused",
                "Fills the focused track"
            ),
            L("placement.first", "First"),
            L("placement.last", "Last")
        )
    }
}
