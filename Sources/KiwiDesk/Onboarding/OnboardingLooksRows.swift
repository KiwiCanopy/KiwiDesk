import KiwiDeskCore
import SwiftUI

/// The looks step's top row: every bundled look, whole on screen,
/// drawn like the Settings look cards (#1684) with the look's own
/// palette painted on.
struct OnboardingLookRow: View {
    let looks: [ShelfLook]
    let live: TilingSettings
    let spaceLabels: [SpaceGlyph]
    let palette: (ShelfLook) -> ColorPalette?
    let pick: (ShelfLook) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            OnboardingRowHeader(text: L("looks.title", "Looks"))
            HStack(alignment: .top, spacing: 8) {
                ForEach(looks, id: \.name) { look in
                    tile(look)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L("looks.title", "Looks"))
    }

    /// The styling alone marks a look; the colours are the row
    /// below's (the Settings card's rule).
    private func tile(_ look: ShelfLook) -> some View {
        let applied = look.isApplied(to: live)
        return Button {
            pick(look)
        } label: {
            PaletteTile(
                name: look.name,
                caption: caption(look),
                isApplied: applied,
                captionLines: 3
            ) {
                LookPlate(settings: preview(look), spaceLabels: spaceLabels)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(applied ? [.isSelected] : [])
    }

    /// Glass needs none here: it is the look already on screen.
    private func caption(_ look: ShelfLook) -> String? {
        guard look.name != LookCatalog.defaultName else { return nil }
        return LookDescriptions.caption(for: look.name)
    }

    private func preview(_ look: ShelfLook) -> TilingSettings {
        KiwiCore.painted(live, look: look, palette: palette(look))
    }
}

/// The looks step's bottom row: the bundled palettes, then the
/// user's, scrolled so the live palette is in view — a look's
/// palette may sit past the visible end when the look is picked.
struct OnboardingPaletteRow: View {
    let palettes: [ColorPalette]
    let live: TilingSettings
    let reduceMotion: Bool
    let pick: (ColorPalette) -> Void

    private var liveColors: [String: String] {
        ColorPaletteKeys.extract(from: live)
    }

    private var applied: String? {
        let colors = liveColors
        return palettes.first { $0.isApplied(matching: colors) }?.name
    }

    var body: some View {
        let colors = liveColors
        VStack(alignment: .leading, spacing: 6) {
            OnboardingRowHeader(
                text: L("palettes.title", "Color palette")
            )
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 8) {
                        ForEach(palettes, id: \.name) { palette in
                            tile(palette, colors: colors)
                                .frame(width: 108)
                                .id(palette.name)
                        }
                    }
                    .padding(.bottom, 8)
                }
                .onAppear { reveal(applied, proxy, animated: false) }
                .onChange(of: applied) { _, name in
                    reveal(name, proxy, animated: true)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L("palettes.title", "Color palette"))
    }

    private func tile(
        _ palette: ColorPalette,
        colors: [String: String]
    ) -> some View {
        let isApplied = palette.isApplied(matching: colors)
        return Button {
            pick(palette)
        } label: {
            PaletteTile(name: palette.name, isApplied: isApplied) {
                PaletteSceneThumbnail(
                    palette: palette,
                    drawsBorder: live.kiwishelf.border,
                    drawsSheen: live.borderStyle.sheen
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isApplied ? [.isSelected] : [])
    }

    private func reveal(
        _ name: String?,
        _ proxy: ScrollViewProxy,
        animated: Bool
    ) {
        guard let name else { return }
        withAnimation(animated && !reduceMotion ? .default : nil) {
            proxy.scrollTo(name, anchor: .center)
        }
    }
}

/// A row's heading, in the tour's type scale.
struct OnboardingRowHeader: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(SettingsTheme.ink2)
            .accessibilityAddTraits(.isHeader)
    }
}
