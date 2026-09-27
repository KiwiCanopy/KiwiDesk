import KiwiDeskCore
import SwiftUI

/// The sheen's one centre-origin slider (#1644, ui-designer): a
/// signed strength that fills from 0 either way, no end labels, no
/// detent — the 0.05 grid lands on 0, which reads **Off**. Never
/// greyed: the sheen is not glass.
struct SheenRow: View {
    @Binding var strength: CGFloat

    static var label: String { L("colors.sheen", "Sheen") }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            SettingsRowShape {
                SettingsRowLabel(label: Self.label, help: nil)
            } control: {
                HStack {
                    SettingsSlider(
                        value: Binding(
                            get: { Double(strength) },
                            set: {
                                strength = BorderStyle.clampSheen(
                                    CGFloat($0)
                                )
                            }
                        ),
                        range: -1...1,
                        step: 0.05,
                        label: Self.label,
                        spokenValue: SettingsValueReadout.sheenSpoken(
                            strength
                        ),
                        origin: 0
                    )
                    Text(SettingsValueReadout.sheen(strength))
                        .settingsReadout()
                        .frame(
                            width: SettingsMetrics.readoutColumn,
                            alignment: .trailing
                        )
                        .foregroundStyle(.secondary)
                        .font(.body.monospacedDigit())
                }
            }
            Text(
                L(
                    "colors.sheen.caption",
                    "Lightens the top of the focus border, the bars' "
                        + "highlight and border, and drag borders; "
                        + "slide left to darken it instead."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
