import SwiftUI

/// A slider with its readout and, beneath, the presets that snap
/// it — the split ratio's shape (`RatioRow`), shared with the
/// KiwiShelf font weight (#1681). The readout is visual only; the
/// slider speaks `spokenValue`.
struct SliderPresetRow<Presets: View>: View {
    let label: String
    var help: String? = nil
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let readout: String
    let spokenValue: String
    @ViewBuilder let presets: Presets

    var body: some View {
        SettingsRowShape {
            SettingsRowLabel(label: label, help: help)
        } control: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    SettingsSlider(
                        value: $value,
                        range: range,
                        step: step,
                        label: label,
                        spokenValue: spokenValue
                    )
                    Text(readout)
                        .settingsReadout()
                        .frame(
                            width: SettingsMetrics.readoutColumn,
                            alignment: .trailing
                        )
                        .foregroundStyle(.secondary)
                        .font(.body.monospacedDigit())
                }
                presets
            }
        }
    }
}
