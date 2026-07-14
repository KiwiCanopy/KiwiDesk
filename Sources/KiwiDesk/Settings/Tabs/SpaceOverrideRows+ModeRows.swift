import KiwiDeskCore
import SwiftUI

/// The Grid / Monocle / Track per-space override rows, split out
/// of `SpaceOverrideRows` so each file stays under the line
/// ceiling. `g` and `binding(_:_:_:)` are internal on the base
/// type; these builders are called from its `modeRows` switch.
extension SpaceOverrideRows {
    @ViewBuilder
    var gridRows: some View {
        OverridePickerRow(
            label: L("scroll_grid.grid_type", "Grid type"),
            value: binding(\.grid.override, space, \.type),
            global: g.grid.type,
            options: [
                (.dynamic, L("scroll_grid.dynamic", "Dynamic")),
                (.rigid, L("scroll_grid.rigid", "Rigid")),
            ]
        )
        OverrideToggleRow(
            label: L(
                "scroll_grid.fill_empty_space",
                "Fill empty space"
            ),
            value: binding(
                \.grid.override,
                space,
                \.fillEmptySpace
            ),
            global: g.grid.fillEmptySpace
        )
        // "Arrange: Columns first / Rows first" (#217) — GUI
        // label only; the `split_direction` wire vocab is kept.
        OverridePickerRow(
            label: L("scroll_grid.arrange", "Arrange"),
            value: binding(
                \.grid.override,
                space,
                \.splitDirection
            ),
            global: g.grid.splitDirection,
            options: [
                (
                    .horizontal,
                    L(
                        "scroll_grid.arrange.columns_first",
                        "Columns first"
                    )
                ),
                (
                    .vertical,
                    L(
                        "scroll_grid.arrange.rows_first",
                        "Rows first"
                    )
                ),
            ]
        )
        OverrideStepperRow(
            label: L("scroll_grid.columns", "Columns"),
            value: binding(\.grid.override, space, \.columns),
            global: g.grid.columns,
            range: 1...10
        )
        OverrideStepperRow(
            label: L("scroll_grid.rows", "Rows"),
            value: binding(\.grid.override, space, \.rows),
            global: g.grid.rows,
            range: 1...10
        )
    }

    @ViewBuilder
    var monocleRows: some View {
        OverridePickerRow(
            label: L("scroll_grid.orientation", "Orientation"),
            value: binding(
                \.monocle.override,
                space,
                \.orientation
            ),
            global: g.monocle.orientation,
            options: [
                (
                    .horizontal,
                    L("scroll_grid.horizontal", "Horizontal")
                ),
                (.vertical, L("scroll_grid.vertical", "Vertical")),
            ]
        )
    }

    @ViewBuilder
    var trackRows: some View {
        OverridePickerRow(
            // "Arrange: Columns / Rows" (#217 pattern) — GUI label
            // only; wire `track.axis` stays horizontal/vertical.
            label: L("scroll_grid.arrange", "Arrange"),
            value: binding(\.track.override, space, \.axis),
            global: g.track.axis,
            options: [
                (
                    .vertical,
                    L("scroll_grid.arrange.columns", "Columns")
                ),
                (
                    .horizontal,
                    L("scroll_grid.arrange.rows", "Rows")
                ),
            ]
        )
        OverrideStepperRow(
            label: L("track.count", "Track limit"),
            value: binding(
                \.track.override,
                space,
                \.count
            ),
            global: g.track.count,
            range: 0...10
        )
        OverridePickerRow(
            label: L("layout_params.overflow", "Overflow"),
            value: binding(
                \.track.override,
                space,
                \.overflowStyle
            ),
            global: g.track.overflowStyle,
            options: [
                (
                    .cascadeOverflow,
                    L(
                        "layout_params.cascade_overflow",
                        "Cascade overflow"
                    )
                ),
                (
                    .cascadeAll,
                    L(
                        "layout_params.cascade_all",
                        "Cascade all"
                    )
                ),
            ]
        )
    }
}
