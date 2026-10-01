import Foundation
import Testing

@testable import KiwiDeskCore

/// A colour whose Automatic follows another (#1856): the one
/// resolver a picture of a palette reads agrees with what the
/// renderer draws, and the front chip's ring, as every bundled
/// palette resolves it, keeps the colour-vision distance from the
/// active Space's ring that the two-accent model rests on.
@Suite("Palette follower colours")
struct ColorPaletteFollowerTests {
    /// What the renderer draws for each follower — one entry per
    /// `ColorPaletteKeys.followers` key, or the clause below reds.
    private static let drawn: [String: @Sendable (TilingSettings) -> String] =
        [
            "space_bar.focused_highlight_color": {
                $0.spaceBarStyle.resolvedFocusedHighlightColor
            }
        ]

    @Test("The resolver reads what the renderer draws")
    func resolverMatchesRenderer() throws {
        #expect(
            Set(Self.drawn.keys) == Set(ColorPaletteKeys.followers.keys)
        )
        for (follower, leader) in ColorPaletteKeys.followers {
            var settings = TilingSettings()
            ColorPalette(
                name: "t",
                colors: [leader: "#ABCDEF", follower: ""]
            ).apply(to: &settings)
            let colors = ColorPaletteKeys.extract(from: settings)
            let draws = try #require(Self.drawn[follower])
            #expect(
                ColorPaletteKeys.resolved(follower, in: colors)
                    == draws(settings)
            )
            #expect(draws(settings) == "#ABCDEF")
        }
    }

    @Test("Every bundled front ring stays apart from the Space ring")
    func bundledRingsSeparate() throws {
        #expect(!PaletteCatalog.authored().isEmpty)
        for palette in PaletteCatalog.bundled() {
            let painted = palette.paintedColors
            let ring = ColorPaletteKeys.resolved(
                "space_bar.focused_highlight_color",
                in: painted
            )
            let space = try #require(painted["kiwishelf.highlight_color"])
            guard let gap = ColorVision.separation(space, ring) else {
                Issue.record("\(palette.name): unparseable ring")
                continue
            }
            #expect(
                gap >= ColorVision.separationFloor,
                "\(palette.name): \(space) vs front \(ring) by \(gap)"
            )
        }
    }
}
