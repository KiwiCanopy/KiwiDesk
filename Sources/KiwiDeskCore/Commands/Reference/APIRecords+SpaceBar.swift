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
        "set_reserve": APIRecord(
            "Reserves the Space Bar's strip; false draws it over "
                + "the windows, the strip unclickable.",
            .boolean("reserve")
        ),
        "set_edge": APIRecord(
            "Sets the Space Bar's screen edge; on the App Bar's "
                + "edge the two share one KiwiShelf.",
            .choice("edge", AppBarEdge.self)
        ),
        "set_glyph_span": APIRecord(
            "Sets how many glyphs a Space item shows "
                + "around its focus.",
            .integer("glyphs")
        ),
        "set_glyph_gap": APIRecord(
            "Sets the room in points between app glyphs inside a "
                + "Space item; 0 abuts them.",
            .number("gap")
        ),
        "set_inactive_content": APIRecord(
            "Sets what a Space off screen shows: its apps, or its "
                + "identifier with a window count.",
            .choice(
                "content",
                SpaceBarStyle.InactiveContent.self
            )
        ),
        "set_item_label": APIRecord(
            "Sets what names a Space item: its identifier, or its "
                + "current layout's symbol.",
            .choice("label", SpaceBarStyle.ItemLabel.self)
        ),
        "set_active_indicator": APIRecord(
            "Sets how the active Space is marked.",
            .choice(
                "indicator",
                AppBarStyle.ActiveIndicator.self
            )
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
        "set_front_app_title_cap": APIRecord(
            "Sets how many characters of the front window's "
                + "title the front-app segment shows.",
            .integer("characters")
        ),
        "set_group_adjacent_windows": APIRecord(
            "Collapses adjacent same-app windows in a Space item "
                + "into one glyph with a count badge.",
            .boolean("enabled")
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
        "set_focused_item_color": APIRecord(
            "Sets the color of the focused window's glyph and "
                + "front-app segment.",
            .color("hex")
        ),
        "set_focused_highlight_color": APIRecord(
            "Sets the front-app segment's indicator color; empty "
                + "follows the focused item color.",
            .color("hex")
        ),
    ]
}
