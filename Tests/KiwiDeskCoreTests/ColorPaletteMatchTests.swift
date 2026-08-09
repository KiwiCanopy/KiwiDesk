import Foundation
import Testing

@testable import KiwiDeskCore

/// `ColorPalette.isApplied(to:)` (#757) — what the shelf's
/// applied mark reads. A palette paints one-shot, so the mark is
/// computed from the live colours rather than remembered; these
/// pin that it answers the palette's own key set and that it
/// stops saying yes the moment a colour is edited by hand.
@Suite("Palette applied match")
struct ColorPaletteMatchTests {
    @Test("Every bundled palette reads applied after applying it")
    func bundledRoundTrips() {
        for palette in PaletteCatalog.bundled() {
            var settings = TilingSettings()
            palette.apply(to: &settings)
            #expect(
                palette.isApplied(to: settings),
                Comment(rawValue: palette.name)
            )
        }
    }

    /// The shipped defaults ARE the default palette, so a fresh
    /// config already reads as wearing it — the shelf marks one
    /// card on first open rather than none.
    @Test("Fresh settings read as the default palette")
    func freshSettingsWearTheDefault() {
        #expect(
            PaletteCatalog.defaultPalette()
                .isApplied(to: TilingSettings())
        )
    }

    /// One hand edit in Advanced Colours unmarks the card. This
    /// is the whole reason the mark is computed and not stored.
    @Test("A hand-edited colour drops the mark")
    func handEditDropsTheMark() {
        var settings = TilingSettings()
        let palette = PaletteCatalog.defaultPalette()
        settings.appBarStyle.fillColor = "#123456FF"
        #expect(!palette.isApplied(to: settings))
    }

    /// A different palette's colours do not read as this one's.
    @Test("Another palette's colours do not match")
    func anotherPaletteDoesNotMatch() throws {
        let authored = PaletteCatalog.authored()
        let first = try #require(authored.first)
        var settings = TilingSettings()
        first.apply(to: &settings)
        for other in authored.dropFirst() {
            #expect(
                !other.isApplied(to: settings),
                Comment(rawValue: other.name)
            )
        }
    }

    /// A sparse palette is applied when the colours it PAINTS
    /// match — the rest of the surface is not its claim.
    @Test("A sparse palette answers on its own keys")
    func sparsePaletteAnswersOnItsOwnKeys() {
        var settings = TilingSettings()
        let sparse = ColorPalette(
            name: "S",
            colors: ["app_bar.fill_color": "#101010B3"]
        )
        #expect(!sparse.isApplied(to: settings))
        sparse.apply(to: &settings)
        #expect(sparse.isApplied(to: settings))
        // An unrelated colour moving leaves the claim intact.
        settings.spaceBarStyle.itemColor = "#ABCDEF"
        #expect(sparse.isApplied(to: settings))
    }

    /// Case and the optional alpha byte are spelling, not colour.
    /// A user who types the palette's own colour back in lower
    /// case has not left the theme.
    @Test("Spelling of a hex does not change the answer")
    func hexSpellingIsNotAColour() {
        var settings = TilingSettings()
        settings.appBarStyle.fillColor = "#8db354ff"
        let palette = ColorPalette(
            name: "C",
            colors: ["app_bar.fill_color": "#8DB354"]
        )
        #expect(palette.isApplied(to: settings))
    }

    /// The mark tints' "Automatic" face is an empty string, which
    /// parses to no colour — it must match itself and nothing
    /// else, or every palette leaving them automatic would read
    /// applied against a config that had painted them.
    @Test("Automatic matches Automatic, not a painted mark")
    func automaticIsItsOwnValue() {
        var settings = TilingSettings()
        let automatic = ColorPalette(
            name: "A",
            colors: ["sticky.color": ""]
        )
        #expect(automatic.isApplied(to: settings))
        settings.stickyStyle.color = "#8B5E3C"
        #expect(!automatic.isApplied(to: settings))
    }

    /// A palette that paints nothing cannot be the applied one —
    /// "every colour matches" is vacuously true over no colours.
    @Test("An empty palette is never applied")
    func emptyPaletteIsNeverApplied() {
        let empty = ColorPalette(name: "E", colors: [:])
        #expect(!empty.isApplied(to: TilingSettings()))
    }

    /// A path the settings do not have is a MISS, never a skip.
    /// An imported palette can carry anything, wire keys are
    /// renamed freely pre-release, and a matcher that ignored
    /// what it could not find would mark a typo'd palette applied
    /// against every possible config — including one whose real
    /// colours it disagrees with.
    @Test("An unknown colour path is never applied")
    func unknownPathIsNeverApplied() {
        let settings = TilingSettings()
        let typo = ColorPalette(
            name: "T",
            colors: ["app_bar.fill_colour": "#14201CB3"]
        )
        #expect(!typo.isApplied(to: settings))
        // And it poisons an otherwise-matching palette rather
        // than being quietly dropped from the comparison.
        let mixed = ColorPalette(
            name: "M",
            colors: [
                "app_bar.fill_color": settings.appBarStyle
                    .fillColor,
                "app_bar.made_up_color": "#123456",
            ]
        )
        #expect(!mixed.isApplied(to: settings))
    }
}
