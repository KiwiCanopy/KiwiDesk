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
                masterOrientation: model.config.settings.stack
                    .masterOrientation,
                stackPosition: model.config.settings.stack
                    .stackPosition,
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
            DropdownRow(
                label: masterOrientationLabel,
                help: LayoutHelp.masterOrientation
            ) {
                orientationPicker(
                    masterOrientationLabel,
                    selection: stack.masterOrientation
                )
            }
            // Orientation only matters with several masters;
            // greyed (not hidden) at count 1 so its value stays
            // visible (§2.7 grey-don't-hide, #171).
            .disabled(
                model.config.settings.stack.masterCount <= 1
            )
            Divider()
            DropdownRow(
                label: stackPositionLabel,
                help: LayoutHelp.stackPosition
            ) {
                Picker(
                    stackPositionLabel,
                    selection: stack.stackPosition
                ) {
                    Text(L("layout_params.position.top", "Top"))
                        .tag(StackParams.StackPosition.top)
                    Text(
                        L("layout_params.position.right", "Right")
                    )
                    .tag(StackParams.StackPosition.right)
                    Text(
                        L(
                            "layout_params.position.bottom",
                            "Bottom"
                        )
                    )
                    .tag(StackParams.StackPosition.bottom)
                    Text(L("layout_params.position.left", "Left"))
                        .tag(StackParams.StackPosition.left)
                }
            }
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

    private var masterOrientationLabel: String {
        L(
            "layout_params.master_orientation",
            "Master orientation"
        )
    }

    private var stackPositionLabel: String {
        L("layout_params.stack_position", "Stack position")
    }

    /// One vertical/horizontal picker for both orientation
    /// rows — same options, same tags.
    private func orientationPicker(
        _ label: String,
        selection: Binding<StackParams.Orientation>
    ) -> some View {
        Picker(label, selection: selection) {
            Text(
                L(
                    "layout_params.orientation.vertical",
                    "Vertical"
                )
            )
            .tag(StackParams.Orientation.vertical)
            Text(
                L(
                    "layout_params.orientation.horizontal",
                    "Horizontal"
                )
            )
            .tag(StackParams.Orientation.horizontal)
        }
    }
}
