import KiwiDeskCore
import SwiftUI

/// Grid, Monocle, and Track per-space override rows.
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
        // Gated on space's resolved value (#520).
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
        // Arrange picker (#217).
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
        // Remote gate anchor sits outside GreyOut (#841).
        remoteGateReference(
            for: .layout(.gridOverrideColumns)
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
            label: L("track.limit", "Track limit"),
            value: binding(
                \.track.override,
                space,
                \.limit
            ),
            global: g.track.limit,
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
        // Remote gate live anchor (#841, #406).
        remoteGateReference(for: .layout(.trackOverrideLimit))
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

extension SpaceOverrideRows {
    /// Remote gate cross-reference link row
    /// (`docs/ui-patterns.md`, `LayoutCard`,
    /// `SidebarCrossReferenceTests`, #841).
    @ViewBuilder
    func remoteGateReference(for key: SettingKey) -> some View {
        if let reason = gates.inertReason(for: key),
            SpacesGateHelp.remote.contains(reason),
            let prose = SpacesGateHelp.crossReference(for: reason)
        {
            CrossReferenceRow(
                prose: prose,
                linkTitle: SettingsDestination.layoutDefaults
                    .title,
                destination: .layoutDefaults
            )
        }
    }
}
