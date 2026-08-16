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
        // The remote gate's live anchor (#841). OUTSIDE the
        // `GreyOut` on purpose: it is the one thing on this
        // surface that must stay clickable while the rows above
        // it are inert, and a pointer inside the dimmed subtree
        // is exactly the dead end the rule names.
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
        // The remote gate's live anchor (#841) — see the twin on
        // the grid rows for why it sits outside the `GreyOut`.
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
    /// The live pointer a REMOTE gate owes (#841).
    ///
    /// `GateReasonPlacement` classifies three rows here `.remote`
    /// — their gating switch has no row in this editor, so the
    /// reader cannot look up and find it. `docs/ui-patterns.md`
    /// rules that such a gate takes a live anchor whose sentence
    /// **names the destination to go to**, and that if the
    /// sentence names one it must be a `CrossReferenceRow`
    /// rather than a `Text`, or the pointer is dead.
    ///
    /// Drawn only while the gate is actually closed: a permanent
    /// "you could change this elsewhere" line under live rows is
    /// noise, and the rule is about answering a dim.
    ///
    /// `LayoutCard`'s app-bar reference is the model this
    /// follows — name the current STATE in the sentence and link
    /// where to change it, so the row is never a dead pointer.
    @ViewBuilder
    func remoteGateReference(for key: SettingKey) -> some View {
        if let reason = gates.inertReason(for: key),
            SpacesGateHelp.remote.contains(reason),
            let prose = SpacesGateHelp.crossReference(for: reason)
        {
            CrossReferenceRow(
                prose: prose,
                // The destination's OWN title, not a new
                // breadcrumb key. `LayoutCard` needs a `▸` head
                // because "App Bar" names no row any sidebar
                // shows; "Layout Defaults" is exactly what the
                // sidebar reads, so the bare title lands the
                // reader on a row they can see. It also carries
                // its own translations already — a fresh
                // breadcrumb key would ship English into ten
                // catalogs and red `SidebarCrossReferenceTests`,
                // which requires each locale to name the
                // destination as that locale renders it.
                linkTitle: SettingsDestination.layoutDefaults
                    .title,
                destination: .layoutDefaults
            )
        }
    }
}
