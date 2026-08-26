import Foundation

/// `animations.*`, `stack.*`, `bsp.*`, `grid.*` and `track.*`
/// (#1033).
///
/// Shapes follow `APIRecords+Scroll.swift`: a global setter
/// takes its value alone, its `_override` twin takes a `.space`
/// first, and an enum-valued argument names the Swift type the
/// decoder uses rather than spelling its cases.
extension APIReference {
    static let animationsRecords: [String: APIRecord] = [
        "set_duration": APIRecord(
            "Sets the general animation duration in milliseconds.",
            .integer("milliseconds")
        ),
        "set_scroll_speed": APIRecord(
            "Sets the scrolling focus-shift duration in "
                + "milliseconds.",
            .integer("milliseconds")
        ),
        "set_on_space_change": APIRecord(
            "Enables or disables animation when switching Spaces.",
            .boolean("enabled")
        ),
        "set_on_scrolling": APIRecord(
            "Enables or disables the layout slide when scrolling.",
            .boolean("enabled")
        ),
        "set_on_window_resize": APIRecord(
            "Enables or disables animation on window resizes.",
            .boolean("enabled")
        ),
        "set_on_window_swap": APIRecord(
            "Enables or disables animation when swapping two "
                + "windows.",
            .boolean("enabled")
        ),
        "set_on_relayout": APIRecord(
            "Enables or disables animation on layout reflows.",
            .boolean("enabled")
        ),
        "set_size_policy": APIRecord(
            "Sets whether window sizes animate smoothly or "
                + "mid-slide.",
            .text("policy")
        ),
        "set_size_rate": APIRecord(
            "Caps the update rate for smooth size changes in "
                + "Hertz.",
            .integer("hertz")
        ),
    ]

    static let stackRecords: [String: APIRecord] = [
        "promote": APIRecord(
            "Moves the focused window to the master zone."
        ),
        "demote": APIRecord(
            "Moves the focused window out of the master zone."
        ),
        "set_master_count": APIRecord(
            "Sets how many windows are in the master zone.",
            .integer("count")
        ),
        "set_master_ratio": APIRecord(
            "Sets the master zone's share of the split axis.",
            .number("ratio")
        ),
        "set_overflow_style": APIRecord(
            "Sets how the stack zone cascades when overflowing.",
            .choice("style", StackParams.OverflowStyle.self)
        ),
        "set_master_orientation": APIRecord(
            "Sets how windows line up within the master zone.",
            .choice("orientation", StackParams.Orientation.self)
        ),
        "set_stack_position": APIRecord(
            "Sets which side of the space the stack zone "
                + "occupies.",
            .choice("position", StackParams.StackPosition.self)
        ),
        "set_new_window_placement": APIRecord(
            "Sets where a new window lands in the stack order.",
            .choice("placement", SpawnPlacement.self)
        ),
        "set_master_count_override": APIRecord(
            "Overrides the master count for one Space.",
            .space("space"),
            .integer("count")
        ),
        "set_master_ratio_override": APIRecord(
            "Overrides the master ratio for one Space.",
            .space("space"),
            .number("ratio")
        ),
        "set_overflow_style_override": APIRecord(
            "Overrides the overflow style for one Space.",
            .space("space"),
            .choice("style", StackParams.OverflowStyle.self)
        ),
        "set_master_orientation_override": APIRecord(
            "Overrides the master orientation for one Space.",
            .space("space"),
            .choice("orientation", StackParams.Orientation.self)
        ),
        "set_stack_position_override": APIRecord(
            "Overrides the stack position for one Space.",
            .space("space"),
            .choice("position", StackParams.StackPosition.self)
        ),
    ]

    static let bspRecords: [String: APIRecord] = [
        "set_strategy": APIRecord(
            "Sets the BSP split strategy.",
            .choice("strategy", BspParams.Strategy.self)
        ),
        "set_ratio_h": APIRecord(
            "Sets the first window's share of side-by-side "
                + "splits.",
            .number("ratio")
        ),
        "set_ratio_v": APIRecord(
            "Sets the first window's share of stacked splits.",
            .number("ratio")
        ),
        "set_new_window_placement": APIRecord(
            "Sets where a new window lands in the BSP layout.",
            .choice("placement", SpawnPlacement.self)
        ),
        "set_strategy_override": APIRecord(
            "Overrides the BSP strategy for one Space.",
            .space("space"),
            .choice("strategy", BspParams.Strategy.self)
        ),
        "set_ratio_h_override": APIRecord(
            "Overrides the side-by-side BSP ratio for one Space.",
            .space("space"),
            .number("ratio")
        ),
        "set_ratio_v_override": APIRecord(
            "Overrides the stacked BSP ratio for one Space.",
            .space("space"),
            .number("ratio")
        ),
    ]

    static let gridRecords: [String: APIRecord] = [
        "set_type": APIRecord(
            "Sets the grid layout type.",
            .choice("type", GridParams.GridType.self)
        ),
        "set_fill_empty_cells": APIRecord(
            "Sets whether windows resize to fill empty cells.",
            .boolean("enabled")
        ),
        "set_split_direction": APIRecord(
            "Sets the grid fill order across rows or columns.",
            .choice("direction", GridParams.SplitDirection.self)
        ),
        "set_dimensions": APIRecord(
            "Locks rigid grid dimensions to given columns and "
                + "rows.",
            .integer("columns"),
            .integer("rows")
        ),
        "set_auto_size": APIRecord(
            "Derives grid dimensions from the screen and window "
                + "size.",
            .boolean("enabled")
        ),
        "set_new_window_placement": APIRecord(
            "Sets where a new window lands in the grid order.",
            .choice("placement", SpawnPlacement.self)
        ),
        "set_type_override": APIRecord(
            "Overrides the grid type for one Space.",
            .space("space"),
            .choice("type", GridParams.GridType.self)
        ),
        "set_fill_empty_cells_override": APIRecord(
            "Overrides empty-cell filling for one Space.",
            .space("space"),
            .boolean("enabled")
        ),
        "set_split_direction_override": APIRecord(
            "Overrides the grid fill order for one Space.",
            .space("space"),
            .choice("direction", GridParams.SplitDirection.self)
        ),
        "set_dimensions_override": APIRecord(
            "Overrides grid dimensions for one Space.",
            .space("space"),
            .integer("columns"),
            .integer("rows")
        ),
        "set_auto_size_override": APIRecord(
            "Overrides the auto-size flag for one Space.",
            .space("space"),
            .boolean("enabled")
        ),
    ]

    static let trackRecords: [String: APIRecord] = [
        "swap": APIRecord(
            "Swaps the focused window's track with the adjacent "
                + "one.",
            .text("direction")
        ),
        "set_axis": APIRecord(
            "Sets whether tracks run vertically or "
                + "horizontally.",
            .choice("axis", TrackParams.Axis.self)
        ),
        "set_limit": APIRecord(
            "Sets the maximum number of normal tracks; 0 is "
                + "auto.",
            .integer("limit")
        ),
        "set_auto_tracks": APIRecord(
            "Sets whether the track limit adjusts automatically.",
            .boolean("enabled")
        ),
        "set_new_window": APIRecord(
            "Sets whether new windows join the track or open a "
                + "new one.",
            .choice("rule", TrackParams.NewWindowTrack.self)
        ),
        "set_new_window_position": APIRecord(
            "Sets where a new window lands within the track "
                + "choice.",
            .choice("placement", SpawnPlacement.self)
        ),
        "set_overflow_style": APIRecord(
            "Sets how the overflow track cascades when "
                + "overflowing.",
            .choice("style", StackParams.OverflowStyle.self)
        ),
        "set_wrap_focus": APIRecord(
            "Wraps focus from either end of the track to the "
                + "other.",
            .boolean("enabled")
        ),
        "set_axis_override": APIRecord(
            "Overrides the track axis for one Space.",
            .space("space"),
            .choice("axis", TrackParams.Axis.self)
        ),
        "set_limit_override": APIRecord(
            "Overrides the track limit for one Space; 0 is auto.",
            .space("space"),
            .integer("limit")
        ),
        "set_auto_tracks_override": APIRecord(
            "Overrides automatic track limits for one Space.",
            .space("space"),
            .boolean("enabled")
        ),
        "set_overflow_style_override": APIRecord(
            "Overrides the track overflow style for one Space.",
            .space("space"),
            .choice("style", StackParams.OverflowStyle.self)
        ),
    ]
}
