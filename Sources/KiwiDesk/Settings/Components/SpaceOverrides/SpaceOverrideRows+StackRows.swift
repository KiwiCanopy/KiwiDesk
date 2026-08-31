import KiwiDeskCore
import SwiftUI

/// Stack per-space override rows for SpaceOverrideRows (#222).
extension SpaceOverrideRows {
    @ViewBuilder
    var stackRows: some View {
        OverrideStepperRow(
            label: L(
                "layout_params.master_count",
                "Master count"
            ),
            value: binding(
                \.stack.override,
                space,
                \.masterCount
            ),
            global: g.stack.masterCount,
            range: 1...5
        )
        OverrideFractionRow(
            label: L(
                "layout_params.master_ratio",
                "Master ratio"
            ),
            value: binding(
                \.stack.override,
                space,
                \.masterRatio
            ),
            global: g.stack.masterRatio
        )
        OverridePickerRow(
            label: L("layout_params.overflow", "Overflow"),
            value: binding(
                \.stack.override,
                space,
                \.overflowStyle
            ),
            global: g.stack.overflowStyle,
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
            ],
            help: LayoutHelp.stackOverflow
        )
        OverridePickerRow(
            label: L(
                "layout_params.stack_position",
                "Stack position"
            ),
            value: binding(
                \.stack.override,
                space,
                \.stackPosition
            ),
            global: g.stack.stackPosition,
            options: [
                (.top, L("layout_params.position.top", "Top")),
                (
                    .right,
                    L("layout_params.position.right", "Right")
                ),
                (
                    .bottom,
                    L(
                        "layout_params.position.bottom",
                        "Bottom"
                    )
                ),
                (
                    .left,
                    L("layout_params.position.left", "Left")
                ),
            ],
            help: LayoutHelp.stackPosition
        )
        OverridePickerRow(
            label: L(
                "layout_params.master_orientation",
                "Master orientation"
            ),
            value: binding(
                \.stack.override,
                space,
                \.masterOrientation
            ),
            global: g.stack.masterOrientation,
            options: [
                (
                    .vertical,
                    L(
                        "layout_params.orientation.vertical",
                        "Vertical"
                    )
                ),
                (
                    .horizontal,
                    L(
                        "layout_params.orientation.horizontal",
                        "Horizontal"
                    )
                ),
            ],
            help: LayoutHelp.masterOrientation
        )
        // Greyed at a resolved master count of 1, like the
        // Layout Defaults picker (§2.7 grey-don't-hide) — this
        // space's own override decides, not the global. The
        // predicate is the census's, resolved once in `SpacesGates`
        // so the row never re-derives it beside the gate.
        .disabled(
            gates.inertReason(
                for: .layout(.stackOverrideMasterOrientation)
            ) != nil
        )
        .help(
            gates.inertReason(
                for: .layout(.stackOverrideMasterOrientation)
            ).map(SpacesGateHelp.sentence) ?? ""
        )
    }
}
