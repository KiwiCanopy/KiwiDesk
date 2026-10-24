import KiwiDeskCore
import SwiftUI

/// "Fill fade" (#2569): how far the KiwiShelf Fill fades across
/// the glass, 0–100 %, 0 reading "Off" — one even colour.
struct FillFadeRow: View {
    @Binding var fade: CGFloat

    static var label: String { L("kiwishelf.fill_fade", "Fill fade") }

    /// Core's range, never a band of the GUI's own (gui.md, #1359).
    static let range: ClosedRange<Double> =
        Double(
            KiwiShelf.fillFadeRange.lowerBound
        )...Double(
            KiwiShelf.fillFadeRange.upperBound
        )

    /// The value as the row and its diff row read it: 0 is "Off".
    @MainActor
    static func readout(_ fade: CGFloat) -> String {
        fade == 0
            ? L("kiwishelf.fill_fade.off", "Off")
            : SettingsValueReadout.percent(Double(fade) / 100)
    }

    private var readout: String { Self.readout(fade) }

    var body: some View {
        SettingsRowShape {
            SettingsRowLabel(
                label: Self.label,
                help: L(
                    "kiwishelf.fill_fade.help",
                    "How far the %1$@ fades across the glass. "
                        + "\u{201C}%2$@\u{201D} is one even color.",
                    L("kiwishelf.color.fill", "Fill"),
                    L("kiwishelf.fill_fade.off", "Off")
                )
            )
        } control: {
            HStack {
                SettingsSlider(
                    value: Binding(
                        get: { Double(fade) },
                        set: { fade = KiwiShelf.clampFillFade(CGFloat($0)) }
                    ),
                    range: Self.range,
                    step: 1,
                    label: Self.label,
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
            }
        }
    }
}
