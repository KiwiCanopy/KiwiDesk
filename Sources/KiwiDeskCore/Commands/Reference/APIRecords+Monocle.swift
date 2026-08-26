import Foundation

/// `monocle.*` — the monocle layout and its App Bar override
/// (#1033).
///
/// Every record here is `.todo()` until phase 2 fills it. The 25
/// `set_app_bar_*` fields are the same values `app_bar.*` sets
/// globally, so `APIRecords+AppBar.swift` and the scrolling
/// layout's identical block in `APIRecords+Scroll.swift` are the
/// pattern to copy — with "for this layout" saying what an
/// override is.
extension APIReference {
    static let monocleRecords: [String: APIRecord] = [
        "set_orientation": .todo(),
        "set_orientation_override": .todo(),
        "set_hide_style": .todo(),
        "set_wrap_focus": .todo(),
        "set_new_window_placement": .todo(),
        "set_app_bar_enabled": .todo(),
        "set_app_bar_edge": .todo(),
        "set_app_bar_alignment": .todo(),
        "set_app_bar_thickness": .todo(),
        "set_app_bar_background_style": .todo(),
        "set_app_bar_liquid_glass": .todo(),
        "set_app_bar_background_fit": .todo(),
        "set_app_bar_active_indicator": .todo(),
        "set_app_bar_item_size": .todo(),
        "set_app_bar_item_gap": .todo(),
        "set_app_bar_content": .todo(),
        "set_app_bar_title_cap": .todo(),
        "set_app_bar_icon_source": .todo(),
        "set_app_bar_font_size": .todo(),
        "set_app_bar_corner_roundness": .todo(),
        "set_app_bar_dim_factor": .todo(),
        "set_app_bar_item_color": .todo(),
        "set_app_bar_fill_color": .todo(),
        "set_app_bar_active_item_color": .todo(),
        "set_app_bar_highlight_color": .todo(),
        "set_app_bar_hover_fill_color": .todo(),
        "set_app_bar_hover_item_color": .todo(),
        "set_app_bar_group_adjacent_windows": .todo(),
        "set_app_bar_group_badge_color": .todo(),
        "set_app_bar_group_badge_text_color": .todo(),
    ]
}
