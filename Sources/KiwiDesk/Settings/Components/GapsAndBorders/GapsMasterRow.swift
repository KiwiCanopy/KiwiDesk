import KiwiDeskCore
import SwiftUI

/// The Outer or Inner gap master (#1383): one slider for every
/// edge it sets, live over a "mixed" readout while those edges
/// differ, its label's `?` saying the first drag converges them.
/// Gaps & Borders and a Space's own gaps (#1775) both draw it, the
/// divergence read from `GapsBordersGates.outerDiffers` /
/// `innerDiffers` over the value each edits.
struct GapsMasterRow: View {
    let label: String
    let value: CGFloat
    let mixed: Bool
    let set: (CGFloat) -> Void

    var body: some View {
        SettingsRowShape {
            SettingsRowLabel(
                label: label,
                help: mixed ? GapsBordersGateHelp.edgesDiffer : nil
            )
        } control: {
            HStack {
                SettingsSlider(
                    value: Binding(
                        get: { Double(value) },
                        set: { set(CGFloat($0)) }
                    ),
                    range: 0...100,
                    step: 1,
                    label: label,
                    spokenValue: readout
                )
                Text(readout)
                    .settingsReadout()
                    .frame(
                        width: SettingsMetrics.readoutColumn,
                        alignment: .trailing
                    )
                    .foregroundStyle(.secondary)
                    .font(.body.monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
    }

    private var readout: String { Self.readout(value, mixed: mixed) }

    /// "mixed" while the edges differ, else the value in points.
    static func readout(_ value: CGFloat, mixed: Bool) -> String {
        mixed ? L("gaps.mixed", "mixed") : "\(Int(value)) pt"
    }
}
