import Foundation

/// `space_bar.*` — the Space Bar's own style (#1033).
///
/// The Space Bar spells its option types as typealiases of the
/// App Bar's, so a `.choice` here names the same Swift type
/// `APIRecords+AppBar.swift` names — read off
/// `SpaceBarCommandSetting.parse`.
extension APIReference {
    static let spaceBarRecords: [String: APIRecord] = [
        "set_enabled": APIRecord(
            "Shows or hides the Space Bar.",
            .boolean("enabled")
        ),
        "set_edge": APIRecord(
            "Sets the screen edge the bar occupies.",
            .choice("edge", AppBarEdge.self)
        ),
        "set_alignment": APIRecord(
            "Places the Space items along the bar.",
            .choice("alignment", AppBarStyle.BarAlignment.self)
        ),
        "set_thickness": APIRecord(
            "Sets the bar's thickness in points, carved out of "
                + "the layout.",
            .number("thickness")
        ),
        "set_item_size": APIRecord(
            "Pins every Space item to one length along the bar; "
                + "0 is auto.",
            .number("size")
        ),
        "set_item_gap": APIRecord(
            "Sets the spacing between Space items in points.",
            .number("gap")
        ),
        "set_font_size": APIRecord(
            "Pins the item font size in points; 0 scales with "
                + "thickness.",
            .number("size")
        ),
        "set_glyph_cap": APIRecord(
            "Sets how many app-group glyphs a Space item shows.",
            .integer("glyphs")
        ),
        "set_icon_source": APIRecord(
            "Sets whether icons come from the app image or the "
                + "bundled glyph font.",
            .choice("source", BarAppIconSource.self)
        ),
        "set_background_style": APIRecord(
            "Sets where the background is drawn: a box per item "
                + "or one shared strip.",
            .choice("style", AppBarStyle.BackgroundStyle.self)
        ),
        "set_liquid_glass": APIRecord(
            "Lays the macOS 26 Liquid Glass finish over the "
                + "Space items.",
            .boolean("enabled")
        ),
        "set_background_fit": APIRecord(
            "Sets how far the shared background strip reaches "
                + "under the items.",
            .choice("fit", AppBarStyle.BackgroundFit.self)
        ),
        "set_active_indicator": APIRecord(
            "Sets how the active Space is marked.",
            .choice(
                "indicator",
                AppBarStyle.ActiveIndicator.self
            )
        ),
        "set_corner_roundness": APIRecord(
            "Sets the corner rounding of boxed items, as a "
                + "percentage of the maximum.",
            .number("percent")
        ),
        "set_dim_factor": APIRecord(
            "Sets the opacity of everything on an inactive Space.",
            .number("factor")
        ),
        "set_active_dim_factor": APIRecord(
            "Sets the opacity of unfocused window glyphs on the "
                + "active Space.",
            .number("factor")
        ),
        "set_show_front_app": APIRecord(
            "Shows a trailing segment with the active Space's "
                + "frontmost window.",
            .boolean("enabled")
        ),
        "set_title_cap": APIRecord(
            "Sets how many characters of the front window's "
                + "title are shown.",
            .integer("characters")
        ),
        "set_hide_empty": APIRecord(
            "Hides Spaces with no windows from the bar.",
            .boolean("enabled")
        ),
        "set_sticky_badge": APIRecord(
            "Shows or hides sticky and floating badges on Space "
                + "items.",
            .boolean("enabled")
        ),
        "set_spring_delay": APIRecord(
            "Sets how long a dragged window hovers before the "
                + "Space springs open.",
            .integer("milliseconds")
        ),
        "set_item_color": APIRecord(
            "Sets the text and glyph color of inactive Space "
                + "items.",
            .color("hex")
        ),
        "set_active_item_color": APIRecord(
            "Sets the identifier and glyph color of the active "
                + "Space item.",
            .color("hex")
        ),
        "set_focused_item_color": APIRecord(
            "Sets the color of the focused window's glyph and "
                + "front-app segment.",
            .color("hex")
        ),
        "set_hover_fill_color": APIRecord(
            "Sets the hover fill on non-active Space items.",
            .color("hex")
        ),
        "set_hover_item_color": APIRecord(
            "Sets the text and glyph color of hovered "
                + "non-active Space items.",
            .color("hex")
        ),
        "set_fill_color": APIRecord(
            "Sets the background fill under the Space items.",
            .color("hex")
        ),
        "set_highlight_color": APIRecord(
            "Sets the color of the active Space indicator.",
            .color("hex")
        ),
        "set_group_badge_color": APIRecord(
            "Sets the background color of Space Bar count and "
                + "overflow badges.",
            .color("hex")
        ),
        "set_group_badge_text_color": APIRecord(
            "Sets the text color of Space Bar count and "
                + "overflow badges.",
            .color("hex")
        ),
    ]
}
