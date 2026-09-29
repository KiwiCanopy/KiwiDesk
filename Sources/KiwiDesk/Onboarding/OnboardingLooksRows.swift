import KiwiDeskCore
import SwiftUI

/// The looks step's top row: every bundled look, drawn like the
/// Settings look cards (#1684) in the look's own colours (#1752),
/// scrolled like the palette row so each caption keeps its width.
struct OnboardingLookRow: View {
    let looks: [ShelfLook]
    let live: TilingSettings
    let spaceLabels: [SpaceGlyph]
    let pick: (ShelfLook) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            OnboardingRowHeader(text: L("looks.title", "Looks"))
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 8) {
                        ForEach(looks, id: \.name) { look in
                            tile(look)
                                .frame(width: 108)
                                .id(look.name)
                        }
                    }
                    .padding(.bottom, 8)
                }
                .onAppear {
                    let applied = looks.first {
                        $0.match(live) != .none
                    }
                    guard let applied else { return }
                    proxy.scrollTo(applied.name, anchor: .center)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L("looks.title", "Looks"))
    }

    /// Core's one reading marks a look (`ShelfLook.match`), the
    /// Settings card's rule: its shape live in other colours keeps
    /// the mark and says so (#1752).
    private func tile(_ look: ShelfLook) -> some View {
        let match = look.match(live)
        let applied = match != .none
        let other = match == .otherColors
        return Button {
            pick(look)
        } label: {
            PaletteTile(
                name: look.name,
                caption: LookDescriptions.caption(for: look.name),
                isApplied: applied,
                note: other
                    ? L("looks.other_colors", "Other colors") : nil,
                appliedSpoken: other
                    ? L(
                        "looks.applied_other_colors",
                        "Applied, with other colors"
                    ) : nil,
                captionLines: 3
            ) {
                LookPlate(settings: preview(look), spaceLabels: spaceLabels)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(applied ? [.isSelected] : [])
    }

    private func preview(_ look: ShelfLook) -> TilingSettings {
        KiwiCore.painted(live, look: look, palette: nil)
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
