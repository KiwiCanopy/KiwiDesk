import Foundation

/// `space_bar.*` — the Space Bar's own style (#1033).
///
/// Every record here is `.todo()` until phase 2 fills it. The
/// Space Bar spells its option types as typealiases of the App
/// Bar's, so a `.choice` here names the same Swift type
/// `APIRecords+AppBar.swift` names — read the field off
/// `SpaceBarCommandSetting.parse`, which is where the Space
/// Bar's own fields (`glyph_cap`, `sticky_badge`,
/// `show_front_app`, `spring_delay`, `active_dim_factor`,
/// `hide_empty`, `focused_item_color`) diverge from it.
extension APIReference {
    static let spaceBarRecords: [String: APIRecord] = [
        "set_enabled": .todo(),
        "set_edge": .todo(),
        "set_alignment": .todo(),
        "set_thickness": .todo(),
        "set_item_size": .todo(),
        "set_item_gap": .todo(),
        "set_font_size": .todo(),
        "set_glyph_cap": .todo(),
        "set_icon_source": .todo(),
        "set_background_style": .todo(),
        "set_liquid_glass": .todo(),
        "set_background_fit": .todo(),
        "set_active_indicator": .todo(),
        "set_corner_roundness": .todo(),
        "set_dim_factor": .todo(),
        "set_active_dim_factor": .todo(),
        "set_show_front_app": .todo(),
        "set_title_cap": .todo(),
        "set_hide_empty": .todo(),
        "set_sticky_badge": .todo(),
        "set_spring_delay": .todo(),
        "set_item_color": .todo(),
        "set_active_item_color": .todo(),
        "set_focused_item_color": .todo(),
        "set_hover_fill_color": .todo(),
        "set_hover_item_color": .todo(),
        "set_fill_color": .todo(),
        "set_highlight_color": .todo(),
        "set_group_badge_color": .todo(),
        "set_group_badge_text_color": .todo(),
    ]
}
