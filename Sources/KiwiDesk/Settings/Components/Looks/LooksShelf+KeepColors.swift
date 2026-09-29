import KiwiDeskCore
import SwiftUI

/// The "Keep previous colors" row under the bundled looks (#1752):
/// what it offers is `KeepColorsOffer`'s, its tick computed from
/// the draft.
extension LooksShelf {
    /// The offer while it still stands over the draft's colours.
    var standingKeepColors: KeepColorsOffer? {
        let live = ColorPaletteKeys.extract(from: model.config.settings)
        return keepColors.flatMap { $0.shows(live) ? $0 : nil }
    }

    @ViewBuilder var keepColorsRow: some View {
        if let offer = standingKeepColors {
            VStack(alignment: .leading, spacing: 2) {
                Toggle(
                    L("looks.keep_previous_colors", "Keep previous colors"),
                    isOn: keepColorsBinding(offer)
                )
                .toggleStyle(.checkbox)
                Text(
                    L(
                        "looks.keep_previous_colors.caption",
                        "These colors aren't saved as a palette."
                    )
                )
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink3)
                .padding(.leading, 20)
            }
        }
    }

    private func keepColorsBinding(
        _ offer: KeepColorsOffer
    ) -> Binding<Bool> {
        Binding(
            get: {
                offer.isTicked(
                    ColorPaletteKeys.extract(from: model.config.settings)
                )
            },
            set: { on in
                keepColorsWrote = model.paintColors(
                    on ? offer.previous : offer.look
                )
            }
        )
    }
}
