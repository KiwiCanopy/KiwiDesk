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
        // Gated on this space's RESOLVED value, like the
        // stack rows do (#520) — the global twin is greyed for
        // a rigid grid, and the per-space row was not.
        OverrideToggleRow(
            label: L(
                "scroll_grid.fill_empty_cells",
                "Fill empty cells"
            ),
            value: binding(
                \.grid.override,
                space,
                \.fillEmptyCells
            ),
            global: g.grid.fillEmptyCells
        )
        .modifier(
            GreyOut(
                active: gates.inertReason(
                    for: .layout(.gridOverrideFillEmptyCells)
                ) != nil,
                help: gates.inertReason(
                    for: .layout(.gridOverrideFillEmptyCells)
                ).map(SpacesGateHelp.sentence) ?? ""
            )
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
        // Auto-size decides both dimensions, so both rows are
        // inert while it resolves on for this space. The field
        // itself has no row here (audit finding 17), so unlike
        // the global editor — where the gating toggle sits
        // directly above — the help has to NAME what is gating.
        Group {
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
        // One grey over both steppers (they share the auto-size
        // predicate), but each gate is consulted by name so the
        // wiring guard sees both.
        .modifier(
            GreyOut(
                active: gates.inertReason(
                    for: .layout(.gridOverrideColumns)
                ) != nil
                    || gates.inertReason(
                        for: .layout(.gridOverrideRows)
                    ) != nil,
                help: gates.inertReason(
                    for: .layout(.gridOverrideColumns)
                ).map(SpacesGateHelp.sentence) ?? ""
            )
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
        // Same shape as the grid dimensions above: automatic
        // tracks makes the limit inert, and the field that says
        // so has no row here.
        OverrideStepperRow(
            label: L("track.limit", "Track limit"),
            value: binding(
                \.track.override,
                space,
                \.limit
            ),
            global: g.track.limit,
            // 1-based like the global stepper and the Columns/
            // Rows rows above: `nil` is the inherit sentinel, so
            // a stored 0 would be a real value resolving to ONE
            // track while Lua's 0 means automatic — two meanings
            // for one field (audit finding 20, #406).
            range: 1...10
        )
        .modifier(
            GreyOut(
                active: gates.inertReason(
                    for: .layout(.trackOverrideLimit)
                ) != nil,
                help: gates.inertReason(
                    for: .layout(.trackOverrideLimit)
                ).map(SpacesGateHelp.sentence) ?? ""
            )
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
