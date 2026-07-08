import KiwiDeskCore
import SwiftUI

/// BSP and Stack tuning. Scrolling and Grid live in
/// `ScrollGridEditor`; shared row helpers are defined here.
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
            GlassSegmentedPicker(
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
            Stepper(
                "Master count: "
                    + "\(model.config.settings.stack.masterCount)",
                value: $model.config.settings.stack.masterCount,
                in: 1...10
            )
            RatioRow(
                label: "Master ratio",
                value: $model.config.settings.stack.masterRatio
            )
            Picker(
                "Overflow",
                selection: $model.config.settings.stack
                    .overflowStyle
            ) {
                Text("Cascade overflow")
                    .tag(StackParams.OverflowStyle.cascadeOverflow)
                Text("Cascade all")
                    .tag(StackParams.OverflowStyle.cascadeAll)
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

/// A pt-valued slider row with a numeric readout, shared by the
/// monocle and drag-visual editors.
struct PtSlider: View {
    let label: String
    @Binding var value: CGFloat
    var range: ClosedRange<Double> = 0...100

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 110, alignment: .leading)
            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { value = CGFloat($0) }
                ),
                in: range,
                step: 1
            )
            Text("\(Int(value)) pt")
                .frame(width: 48, alignment: .trailing)
                .foregroundStyle(.secondary)
                .font(.system(.body, design: .monospaced))
        }
    }
}

/// A 0.1–0.9 ratio slider with a percentage readout.
struct RatioRow: View {
    let label: String
    @Binding var value: Double

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 110, alignment: .leading)
            Slider(value: $value, in: 0.1...0.9, step: 0.01)
            Text("\(Int(value * 100))%")
                .frame(width: 48, alignment: .trailing)
                .foregroundStyle(.secondary)
                .font(.system(.body, design: .monospaced))
        }
    }
}
