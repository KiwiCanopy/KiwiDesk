import KiwiDeskCore
import SwiftUI

/// The shared row vocabulary of the settings tabs. Every row
/// puts its label in `SettingsMetrics.labelColumn` (sliders,
/// dropdowns, segmented pickers) or pushes its control to the
/// trailing edge (steppers), so controls of the same kind line
/// up across sections.

/// A pt-valued slider row with a numeric readout, shared by the
/// monocle and drag-visual editors. The label column comes from
/// the environment, so `OverrideChrome` narrows it once for
/// every row inside.
struct PtSlider: View {
    let label: String
    @Binding var value: CGFloat
    var range: ClosedRange<Double> = 0...100
    @Environment(\.settingsLabelColumn)
    private var labelColumn

    var body: some View {
        HStack {
            Text(label)
                .frame(width: labelColumn, alignment: .leading)
                .lineLimit(1)
            SettingsSlider(
                value: Binding(
                    get: { Double(value) },
                    set: { value = CGFloat($0) }
                ),
                range: range,
                step: 1
            )
            Text("\(Int(value)) pt")
                .frame(
                    width: SettingsMetrics.readoutColumn,
                    alignment: .trailing
                )
                .foregroundStyle(.secondary)
                .font(.system(.body, design: .monospaced))
        }
    }
}

/// A 0.1–0.9 ratio slider with a percentage readout.
struct RatioRow: View {
    let label: String
    @Binding var value: Double
    @Environment(\.settingsLabelColumn)
    private var labelColumn

    var body: some View {
        HStack {
            Text(label)
                .frame(width: labelColumn, alignment: .leading)
                .lineLimit(1)
            SettingsSlider(
                value: $value,
                range: 0.1...0.9,
                step: 0.01
            )
            // Rounded, not truncated: a stored exact 0.29
            // (Lua/profile) must read "29%", not "28%".
            Text("\(Int((value * 100).rounded()))%")
                .frame(
                    width: SettingsMetrics.readoutColumn,
                    alignment: .trailing
                )
                .foregroundStyle(.secondary)
                .font(.system(.body, design: .monospaced))
        }
    }
}

/// A dropdown row on the shared label axis: the visible label
/// sits in the label column and the menu button starts on the
/// control line, like every slider and segmented picker. The
/// picker keeps its own title for accessibility
/// (`labelsHidden` hides it visually only).
struct DropdownRow<P: View>: View {
    let label: String
    @ViewBuilder let picker: P
    @Environment(\.settingsLabelColumn)
    private var labelColumn

    var body: some View {
        HStack {
            Text(label)
                .frame(width: labelColumn, alignment: .leading)
                .lineLimit(1)
            picker
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.large)
            Spacer()
        }
    }
}

/// A stepper row in the duration rows' shape: label leading,
/// the monospaced value plus arrows trailing — the native
/// System-Settings numeric-stepper layout, and a value that
/// reads as editable instead of a sentence with a number in
/// it.
struct StepperRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    init(
        label: String,
        value: Binding<Int>,
        in range: ClosedRange<Int>
    ) {
        self.label = label
        self._value = value
        self.range = range
    }

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Stepper(value: $value, in: range) {
                Text("\(value)")
                    .frame(minWidth: 32, alignment: .trailing)
                    .monospacedDigit()
            }
            .controlSize(.large)
            .accessibilityLabel(label)
            // The custom label view replaces the stepper's
            // announced text, so the current value must ride
            // along explicitly or VoiceOver hears only the
            // name.
            .accessibilityValue("\(value)")
        }
    }
}

/// New-window placement picker shared by every layout (BSP,
/// Stack, Scrolling, Grid).
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
