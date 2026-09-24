import Foundation

/// `app_bar.*` — global App Bar style command records (#1033).
/// An exemplar group: colour setters show `.color`, pickers a
/// `.choice` reading its decoder's cases.
extension APIReference {
    static let appBarRecords: [String: APIRecord] = [
        "set_active_indicator": APIRecord(
            "Sets how the focused window's item is marked.",
            .choice(
                "indicator",
                AppBarStyle.ActiveIndicator.self
            )
        ),
        "set_content": APIRecord(
            "Sets what each item draws: the icon, the window "
                + "title, or both.",
            .choice("content", AppBarStyle.Content.self)
        ),
        "set_title_cap": APIRecord(
            "Sets how many characters of a window title an item "
                + "shows, longer ones ending in an ellipsis.",
            .integer("characters")
        ),
        "set_icon_source": APIRecord(
            "Sets whether icons come from the app image or the "
                + "bundled glyph font.",
            .choice("source", BarAppIconSource.self)
        ),
        "set_dim_factor": APIRecord(
            "Sets the opacity of an inactive item's untinted "
                + "icon.",
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
