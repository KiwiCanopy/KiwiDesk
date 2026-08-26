import Foundation

/// `app_bar.*` — the global App Bar style (#1033).
///
/// **An exemplar group: every record here is written.** The
/// color setters show the `.color` shape, the pickers show a
/// `.choice` reading its decoder's cases, and the rest are bare
/// numbers. `monocle.set_app_bar_*` and `scroll.set_app_bar_*`
/// are the same fields as per-layout overrides, so a record
/// there says the same thing about the same value.
extension APIReference {
    static let appBarRecords: [String: APIRecord] = [
        "set_edge": APIRecord(
            "Sets the screen edge the bar occupies.",
            .choice("edge", AppBarEdge.self)
        ),
        "set_alignment": APIRecord(
            "Places the item group along the bar while it fits.",
            .choice("alignment", AppBarStyle.BarAlignment.self)
        ),
        "set_thickness": APIRecord(
            "Sets the bar's thickness in points, carved out of "
                + "the layout.",
            .number("thickness")
        ),
        "set_background_style": APIRecord(
            "Sets where the background is drawn: a box per item "
                + "or one shared plate.",
            .choice("style", AppBarStyle.BackgroundStyle.self)
        ),
        "set_liquid_glass": APIRecord(
            "Lays a macOS 26 Liquid Glass material over the item "
                + "backgrounds.",
            .boolean("enabled")
        ),
        "set_background_fit": APIRecord(
            "Sets how far the shared background plate reaches "
                + "under the items.",
            .choice("fit", AppBarStyle.BackgroundFit.self)
        ),
        "set_active_indicator": APIRecord(
            "Sets how the focused window's item is marked.",
            .choice(
                "indicator",
                AppBarStyle.ActiveIndicator.self
            )
        ),
        "set_item_size": APIRecord(
            "Sets each item's size in points; 0 measures the "
                + "widest item and fits.",
            .number("size")
        ),
        "set_item_gap": APIRecord(
            "Sets the gap between items in points.",
            .number("gap")
        ),
        "set_content": APIRecord(
            "Sets what each item draws: the icon, the window "
                + "title, or both.",
            .choice("content", AppBarStyle.Content.self)
        ),
        "set_title_cap": APIRecord(
            "Sets how many characters of a window title an item "
                + "shows, clamped to 8-80.",
            .integer("characters")
        ),
        "set_icon_source": APIRecord(
            "Sets whether icons come from the app image or the "
                + "bundled glyph font.",
            .choice("source", BarAppIconSource.self)
        ),
        "set_font_size": APIRecord(
            "Pins the item font size in points; 0 scales it with "
                + "the bar thickness.",
            .number("size")
        ),
        "set_corner_roundness": APIRecord(
            "Sets the corner rounding of boxed items, 0 square "
                + "to 100 capsule.",
            .number("percent")
        ),
        "set_dim_factor": APIRecord(
            "Sets the opacity of an inactive item's untinted "
                + "icon, 0.05 to 1.",
            .number("factor")
        ),
        "set_group_adjacent_windows": APIRecord(
            "Collapses adjacent same-app windows into one item "
                + "with a count badge.",
            .boolean("enabled")
        ),
        "set_item_color": APIRecord(
            "Sets an item's text and glyph color.",
            .color("hex")
        ),
        "set_fill_color": APIRecord(
            "Sets the fill under the items — a box each, or the "
                + "shared plate.",
            .color("hex")
        ),
        "set_active_item_color": APIRecord(
            "Sets the text and glyph color of the focused item.",
            .color("hex")
        ),
        "set_highlight_color": APIRecord(
            "Sets the color of the active indicator.",
            .color("hex")
        ),
        "set_hover_fill_color": APIRecord(
            "Sets the hover fill on clickable items.",
            .color("hex")
        ),
        "set_hover_item_color": APIRecord(
            "Sets an item's text color while hovered.",
            .color("hex")
        ),
        "set_group_badge_color": APIRecord(
            "Sets the count badge's background color.",
            .color("hex")
        ),
        "set_group_badge_text_color": APIRecord(
            "Sets the count badge's text color.",
            .color("hex")
        ),
    ]
}
