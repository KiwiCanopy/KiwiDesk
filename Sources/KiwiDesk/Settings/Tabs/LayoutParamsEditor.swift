import KiwiDeskCore
import SwiftUI

/// BSP and Stack tuning. Scrolling and Grid live in
/// `ScrollGridEditor`; the shared row vocabulary lives in
/// `SettingsRows`.
struct LayoutParamsEditor: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            bsp
            stack
        }
    }

    private var bsp: some View {
        SettingsSection(
            L("layout.bsp.name", "Bsp"),
            symbol: LayoutMode.bsp.glyph
        ) {
            SegmentedPicker(
                L("layout_params.split_strategy", "Split strategy"),
                selection: $model.config.settings.bsp
                    .strategy,
                options: [
                    (
                        L(
                            "layout_params.shortest_side",
                            "Shortest side"
                        ),
                        BspParams.Strategy.shortestSide
                    ),
                    (
                        L(
                            "layout_params.alternating",
                            "Alternating"
                        ), .alternating
                    ),
                ]
            )
            RatioRow(
                label: L("layout_params.split_ratio", "Split ratio"),
                value: $model.config.settings.bsp.splitRatio
            )
            Divider()
            PlacementPicker(
                placement: $model.config.settings.bsp
                    .newWindowPlacement
            )
        }
    }

    private var stack: some View {
        SettingsSection(
            L("layout.stack.name", "Stack"),
            symbol: LayoutMode.stack.glyph
        ) {
            StepperRow(
                label: L(
                    "layout_params.master_count",
                    "Master count"
                ),
                value: $model.config.settings.stack.masterCount,
                in: 1...10
            )
            RatioRow(
                label: L(
                    "layout_params.master_ratio",
                    "Master ratio"
                ),
                value: $model.config.settings.stack.masterRatio
            )
            Divider()
            DropdownRow(label: overflowLabel) {
                Picker(
                    overflowLabel,
                    selection: $model.config.settings.stack
                        .overflowStyle
                ) {
                    Text(
                        L(
                            "layout_params.cascade_overflow",
                            "Cascade overflow"
                        )
                    )
                    .tag(
                        StackParams.OverflowStyle
                            .cascadeOverflow
                    )
                    Text(
                        L(
                            "layout_params.cascade_all",
                            "Cascade all"
                        )
                    )
                    .tag(StackParams.OverflowStyle.cascadeAll)
                }
            }
            PlacementPicker(
                placement: $model.config.settings.stack
                    .newWindowPlacement
            )
        }
    }

    private var overflowLabel: String {
        L("layout_params.overflow", "Overflow")
    }
}
