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
        // Remote gate anchor sits OUTSIDE the GreyOut (#841): it
        // is the one thing here that must stay clickable while the
        // rows above are inert — a pointer inside the dimmed
        // subtree is exactly the dead end the rule names.
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
            // 1-based: `nil` is the inherit sentinel, so a stored
            // 0 would be a real value resolving to ONE track while
            // Lua's 0 means automatic — two meanings for one field
            // (audit finding 20, #406).
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
                // The destination's OWN title, never a fresh
                // breadcrumb key: it already carries translations,
                // and `SidebarCrossReferenceTests` requires each
                // locale to name the destination as that locale
                // renders it.
                linkTitle: SettingsDestination.layoutDefaults
                    .title,
                destination: .layoutDefaults
            )
        }
    }
}
