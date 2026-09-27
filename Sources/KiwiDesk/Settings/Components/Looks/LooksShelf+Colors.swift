import KiwiDeskCore
import SwiftUI

/// The colors row under the bundled looks (#1684): what it shows
/// is `LookColorsOffer`'s, its tick computed from the draft.
extension LooksShelf {
    var colorsOffer: LookColorsOffer? {
        guard let applied = justApplied else { return nil }
        return LookColorsOffer.decide(
            look: applied.look,
            before: applied.before,
            palette: model.palette(of: applied.look),
            settings: model.config.settings
        )
    }

    @ViewBuilder var colorsRow: some View {
        switch colorsOffer {
        case .tick(let palette, let before):
            Toggle(
                L(
                    "looks.use_colors",
                    "Use its colors too (%1$@)",
                    palette.name
                ),
                isOn: colorsBinding(palette, before: before)
            )
            .toggleStyle(.checkbox)
        case .paletteGone(let name):
            Text(
                L(
                    "looks.palette_gone",
                    "Its palette “%1$@” is no longer saved.",
                    name
                )
            )
            .font(.caption)
            .foregroundStyle(SettingsTheme.ink3)
        case nil:
            EmptyView()
        }
    }

    private func colorsBinding(
        _ palette: ColorPalette,
        before: ColorPalette
    ) -> Binding<Bool> {
        Binding(
            get: {
                palette.isApplied(
                    matching: ColorPaletteKeys.extract(
                        from: model.config.settings
                    )
                )
            },
            set: { on in
                (on ? palette : before).apply(to: &model.config.settings)
            }
        )
    }
}
