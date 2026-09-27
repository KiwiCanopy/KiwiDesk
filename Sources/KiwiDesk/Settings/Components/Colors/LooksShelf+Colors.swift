import KiwiDeskCore
import SwiftUI

/// The colors row under the bundled looks (#1684): offered only for
/// the look a click just applied, its tick COMPUTED from the draft
/// — checked while the look's palette reads applied — and gone
/// once the user's own edits supersede the choice, so a tick can
/// never restore over them.
extension LooksShelf {
    /// What the row offers, or nil while there is nothing to say.
    enum ColorsOffer {
        case tick(palette: ColorPalette, before: ColorPalette)
        case paletteGone(String)
    }

    var colorsOffer: ColorsOffer? {
        guard let applied = justApplied,
            applied.look.isApplied(to: model.config.settings),
            let name = applied.look.palette
        else { return nil }
        guard let palette = model.palette(of: applied.look) else {
            return .paletteGone(name)
        }
        let before = ColorPalette(name: "", colors: applied.before)
        // Already this palette before the click: nothing to undo.
        guard !palette.isApplied(matching: applied.before) else {
            return nil
        }
        let live = ColorPaletteKeys.extract(from: model.config.settings)
        guard
            palette.isApplied(matching: live)
                || before.isApplied(matching: live)
        else { return nil }
        return .tick(palette: palette, before: before)
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
