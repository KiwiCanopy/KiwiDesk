import Foundation

/// `animations.*`, `stack.*`, `bsp.*` and `grid.*` (#1033).
///
/// Every record here is `.todo()` until phase 2 fills it. Copy
/// the shapes from `APIRecords+Scroll.swift`: a global setter
/// takes its value alone, its `_override` twin takes a `.space`
/// first, and an enum-valued argument names the Swift type the
/// decoder uses rather than spelling its cases.
extension APIReference {
    static let animationsRecords: [String: APIRecord] = [
        "set_duration": .todo(),
        "set_scroll_speed": .todo(),
        "set_on_space_change": .todo(),
        "set_on_scrolling": .todo(),
        "set_on_window_resize": .todo(),
        "set_on_window_swap": .todo(),
        "set_on_relayout": .todo(),
        "set_size_policy": .todo(),
        "set_size_rate": .todo(),
    ]

    static let stackRecords: [String: APIRecord] = [
        "promote": .todo(),
        "demote": .todo(),
        "set_master_count": .todo(),
        "set_master_ratio": .todo(),
        "set_overflow_style": .todo(),
        "set_master_orientation": .todo(),
        "set_stack_position": .todo(),
        "set_new_window_placement": .todo(),
        "set_master_count_override": .todo(),
        "set_master_ratio_override": .todo(),
        "set_overflow_style_override": .todo(),
        "set_master_orientation_override": .todo(),
        "set_stack_position_override": .todo(),
    ]

    static let bspRecords: [String: APIRecord] = [
        "set_strategy": .todo(),
        "set_ratio_h": .todo(),
        "set_ratio_v": .todo(),
        "set_new_window_placement": .todo(),
        "set_strategy_override": .todo(),
        "set_ratio_h_override": .todo(),
        "set_ratio_v_override": .todo(),
    ]

    static let gridRecords: [String: APIRecord] = [
        "set_type": .todo(),
        "set_fill_empty_cells": .todo(),
        "set_split_direction": .todo(),
        "set_dimensions": .todo(),
        "set_auto_size": .todo(),
        "set_new_window_placement": .todo(),
        "set_type_override": .todo(),
        "set_fill_empty_cells_override": .todo(),
        "set_split_direction_override": .todo(),
        "set_dimensions_override": .todo(),
        "set_auto_size_override": .todo(),
    ]

    static let trackRecords: [String: APIRecord] = [
        "swap": .todo(),
        "set_axis": .todo(),
        "set_limit": .todo(),
        "set_auto_tracks": .todo(),
        "set_new_window": .todo(),
        "set_new_window_position": .todo(),
        "set_overflow_style": .todo(),
        "set_wrap_focus": .todo(),
        "set_axis_override": .todo(),
        "set_limit_override": .todo(),
        "set_auto_tracks_override": .todo(),
        "set_overflow_style_override": .todo(),
    ]
}
