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
            SegmentedPicker(
                masterOrientationLabel,
                selection: stack.masterOrientation,
                options: [
                    (
                        L(
                            "layout_params.orientation.vertical",
                            "Vertical"
                        ),
                        .vertical
                    ),
                    (
                        L(
                            "layout_params.orientation.horizontal",
                            "Horizontal"
                        ),
                        .horizontal
                    ),
                ],
                help: LayoutHelp.masterOrientation
            )
            // Orientation only matters with several masters;
            // greyed (not hidden) at count 1 so its value stays
            // visible (§2.7 grey-don't-hide, #171).
            .disabled(
                model.config.settings.stack.masterCount <= 1
            )
            Divider()
            SegmentedPicker(
                stackPositionLabel,
                selection: stack.stackPosition,
                options: [
                    (L("layout_params.position.top", "Top"), .top),
                    (
                        L("layout_params.position.right", "Right"),
                        .right
                    ),
                    (
                        L(
                            "layout_params.position.bottom",
                            "Bottom"
                        ),
                        .bottom
                    ),
                    (
                        L("layout_params.position.left", "Left"),
                        .left
                    ),
                ],
                help: LayoutHelp.stackPosition
            )
            Divider()
            SegmentedPicker(
                overflowLabel,
                selection: stack.overflowStyle,
                options: [
                    (
                        L(
                            "layout_params.cascade_overflow",
                            "Cascade overflow"
                        ),
                        .cascadeOverflow
                    ),
                    (
                        L(
                            "layout_params.cascade_all",
                            "Cascade all"
                        ),
                        .cascadeAll
                    ),
                ],
                help: LayoutHelp.stackOverflow
            )
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
}
