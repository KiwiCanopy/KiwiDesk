import KiwiDeskCore
import SwiftUI

/// Stack tuning — one mode's tab in Layout Defaults (#204).
/// Split out of the former `LayoutParamsEditor`; the schematic
/// (#125) leads the section.
struct StackEditor: View {
    @ObservedObject var model: SettingsModel

    private var stack: Binding<StackParams> {
        $model.config.settings.stack
    }

    var body: some View {
        SettingsSection(
            L("layout.stack.name", "Stack"),
            symbol: LayoutMode.stack.glyph
        ) {
            StackSchematic(
                masterCount: model.config.settings.stack
                    .masterCount,
                masterRatio: model.config.settings.stack
                    .masterRatio,
                overflowStyle: model.config.settings.stack
                    .overflowStyle,
                placement: model.config.settings.stack
                    .newWindowPlacement
            )
            StepperRow(
                label: L(
                    "layout_params.master_count",
                    "Master count"
                ),
                value: stack.masterCount,
                in: 1...10
            )
            RatioRow(
                label: L(
                    "layout_params.master_ratio",
                    "Master ratio"
                ),
                value: stack.masterRatio
            )
            Divider()
            DropdownRow(
                label: overflowLabel,
                help: LayoutHelp.stackOverflow
            ) {
                Picker(
                    overflowLabel,
                    selection: stack.overflowStyle
                ) {
                    Text(
                        L(
                            "layout_params.cascade_overflow",
                            "Cascade overflow"
                        )
                    )
                    .tag(
                        StackParams.OverflowStyle.cascadeOverflow
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
            PlacementPicker(placement: stack.newWindowPlacement)
        }
    }

    private var overflowLabel: String {
        L("layout_params.overflow", "Overflow")
    }
}
