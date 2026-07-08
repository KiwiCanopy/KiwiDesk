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
        SettingsSection("BSP", symbol: LayoutMode.bsp.glyph) {
            SegmentedPicker(
                "Split strategy",
                selection: $model.config.settings.bsp
                    .strategy,
                options: [
                    (
                        "Shortest side",
                        BspParams.Strategy.shortestSide
                    ),
                    ("Alternating", .alternating),
                ]
            )
            RatioRow(
                label: "Split ratio",
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
            "Stack",
            symbol: LayoutMode.stack.glyph
        ) {
            StepperRow(
                label: "Master count",
                value: $model.config.settings.stack.masterCount,
                in: 1...10
            )
            RatioRow(
                label: "Master ratio",
                value: $model.config.settings.stack.masterRatio
            )
            Divider()
            DropdownRow(label: "Overflow") {
                Picker(
                    "Overflow",
                    selection: $model.config.settings.stack
                        .overflowStyle
                ) {
                    Text("Cascade overflow")
                        .tag(
                            StackParams.OverflowStyle
                                .cascadeOverflow
                        )
                    Text("Cascade all")
                        .tag(StackParams.OverflowStyle.cascadeAll)
                }
            }
            PlacementPicker(
                placement: $model.config.settings.stack
                    .newWindowPlacement
            )
        }
    }
}

/// New-window placement picker shared by every layout.
struct PlacementPicker: View {
    @Binding var placement: SpawnPlacement

    var body: some View {
        DropdownRow(label: "New window") {
            Picker("New window", selection: $placement) {
                Text("First").tag(SpawnPlacement.first)
                Text("Last").tag(SpawnPlacement.last)
                Text("Before focused")
                    .tag(SpawnPlacement.beforeFocused)
                Text("After focused")
                    .tag(SpawnPlacement.afterFocused)
            }
        }
    }
}
