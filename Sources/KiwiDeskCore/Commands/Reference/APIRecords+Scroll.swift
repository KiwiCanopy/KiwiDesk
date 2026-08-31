import Foundation

/// `scroll.*` — scrolling layout command records (#1033).
extension APIReference {
    static let scrollRecords: [String: APIRecord] = [
        "set_slot_size": APIRecord(
            "Sets the column or row size in points; a \"NN%\" "
                + "string is a fraction, 0 is auto.",
            .number("size")
        ),
        "set_anchor": APIRecord(
            "Sets where the focused window comes to rest in the "
                + "viewport.",
            .choice("anchor", ScrollingParams.Anchor.self)
        ),
        "set_orientation": APIRecord(
            "Sets whether columns scroll left/right or rows "
                + "scroll up/down.",
            .choice(
                "orientation",
                ScrollingParams.Orientation.self
            )
        ),
        "set_new_window_placement": APIRecord(
            "Sets where a new window lands in the row.",
            .choice("placement", SpawnPlacement.self)
        ),
        "set_wrap_focus": APIRecord(
            "Wraps focus from either end of the row to the far "
                + "end.",
            .boolean("enabled")
        ),
        "set_slot_size_override": APIRecord(
            "Overrides the slot size for one Space; same value "
                + "shape as the global setter.",
            .space("space"),
            .number("size")
        ),
        "set_anchor_override": APIRecord(
            "Overrides the anchor for one Space.",
            .space("space"),
            .choice("anchor", ScrollingParams.Anchor.self)
        ),
        "set_orientation_override": APIRecord(
            "Overrides the orientation for one Space.",
            .space("space"),
            .choice(
                "orientation",
                ScrollingParams.Orientation.self
            )
        ),
        "set_app_bar_enabled": APIRecord(
            "Shows or hides the App Bar in the scrolling layout.",
            .boolean("enabled")
        ),
        "set_app_bar_edge": APIRecord(
            "Overrides the App Bar's screen edge for this layout.",
            .choice("edge", AppBarEdge.self)
        ),
        "set_app_bar_alignment": APIRecord(
            "Overrides the App Bar's item alignment for this "
                + "layout.",
            .choice("alignment", AppBarStyle.BarAlignment.self)
        ),
        "set_app_bar_thickness": APIRecord(
            "Overrides the App Bar's thickness for this layout.",
            .number("thickness")
        ),
        "set_app_bar_background_style": APIRecord(
            "Overrides where the App Bar's background is drawn "
                + "for this layout.",
            .choice("style", AppBarStyle.BackgroundStyle.self)
        ),
        "set_app_bar_liquid_glass": APIRecord(
            "Overrides the App Bar's Liquid Glass finish for "
                + "this layout.",
            .boolean("enabled")
        ),
        "set_app_bar_background_fit": APIRecord(
            "Overrides how far the App Bar's plate reaches for "
                + "this layout.",
            .choice("fit", AppBarStyle.BackgroundFit.self)
        ),
        "set_app_bar_active_indicator": APIRecord(
            "Overrides the App Bar's focus marker for this "
                + "layout.",
            .choice(
                "indicator",
                AppBarStyle.ActiveIndicator.self
            )
        ),
        "set_app_bar_item_size": APIRecord(
            "Overrides the App Bar's item size for this layout.",
            .number("size")
        ),
        "set_app_bar_item_gap": APIRecord(
            "Overrides the App Bar's item gap for this layout.",
            .number("gap")
        ),
        "set_app_bar_content": APIRecord(
            "Overrides what the App Bar's items draw for this "
                + "layout.",
            .choice("content", AppBarStyle.Content.self)
        ),
        "set_app_bar_title_cap": APIRecord(
            "Overrides the App Bar's title length cap for this "
                + "layout.",
            .integer("characters")
        ),
        "set_app_bar_icon_source": APIRecord(
            "Overrides where the App Bar's icons come from for "
                + "this layout.",
            .choice("source", BarAppIconSource.self)
        ),
        "set_app_bar_font_size": APIRecord(
            "Overrides the App Bar's font size for this layout.",
            .number("size")
        ),
        "set_app_bar_corner_roundness": APIRecord(
            "Overrides the App Bar's corner rounding for this "
                + "layout.",
            .number("percent")
        ),
        "set_app_bar_dim_factor": APIRecord(
            "Overrides the App Bar's inactive-icon opacity for "
                + "this layout.",
            .number("factor")
        ),
        "set_app_bar_group_adjacent_windows": APIRecord(
            "Overrides same-app window grouping in the App Bar "
                + "for this layout.",
            .boolean("enabled")
        ),
        "set_app_bar_item_color": APIRecord(
            "Overrides the App Bar's item color for this layout.",
            .color("hex")
        ),
        "set_app_bar_fill_color": APIRecord(
            "Overrides the App Bar's fill color for this layout.",
            .color("hex")
        ),
        "set_app_bar_active_item_color": APIRecord(
            "Overrides the App Bar's focused-item color for this "
                + "layout.",
            .color("hex")
        ),
        "set_app_bar_highlight_color": APIRecord(
            "Overrides the App Bar's indicator color for this "
                + "layout.",
            .color("hex")
        ),
        "set_app_bar_hover_fill_color": APIRecord(
            "Overrides the App Bar's hover fill for this layout.",
            .color("hex")
        ),
        "set_app_bar_hover_item_color": APIRecord(
            "Overrides the App Bar's hover text color for this "
                + "layout.",
            .color("hex")
        ),
        "set_app_bar_group_badge_color": APIRecord(
            "Overrides the App Bar's count badge color for this "
                + "layout.",
            .color("hex")
        ),
        "set_app_bar_group_badge_text_color": APIRecord(
            "Overrides the App Bar's badge text color for this "
                + "layout.",
            .color("hex")
        ),
    ]
}
