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
        "set_glyph_cap": APIRecord(
            "Sets how many app-group glyphs a Space item shows.",
            .integer("glyphs")
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
    ]
}
