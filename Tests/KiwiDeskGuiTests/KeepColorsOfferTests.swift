import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The "Keep previous colors" row (#1752): offered after a look
/// click only for colours no saved palette brings back, kept across
/// a run of look clicks, and retired by any other colour change.
@Suite("Keep previous colors offer")
struct KeepColorsOfferTests {
    private func look(fill: String) -> ShelfLook {
        var settings = TilingSettings()
        settings.kiwishelf.fillColor = fill
        return ShelfLook(
            name: fill,
            style: [:],
            colors: ColorPaletteKeys.extract(from: settings)
        )
    }

    private func custom() -> TilingSettings {
        var settings = TilingSettings()
        settings.kiwishelf.fillColor = "#0A0B0C"
        return settings
    }

    private func colors(_ settings: TilingSettings) -> [String: String] {
        ColorPaletteKeys.extract(from: settings)
    }

    @Test("unsaved colours are offered back, the row unticked")
    func offersUnsavedColours() throws {
        var settings = custom()
        let first = look(fill: "#111111")
        let offer = try #require(
            KeepColorsOffer.afterClicking(
                first,
                over: settings,
                prior: nil,
                palettes: PaletteCatalog.bundled()
            )
        )
        first.apply(to: &settings)
        #expect(offer.shows(colors(settings)))
        #expect(!offer.isTicked(colors(settings)))
        #expect(offer.previous == colors(custom()))
    }

    @Test("colours a saved palette reproduces are not offered")
    func paletteColoursAreNot() {
        #expect(
            KeepColorsOffer.afterClicking(
                look(fill: "#111111"),
                over: TilingSettings(),
                prior: nil,
                palettes: PaletteCatalog.bundled()
            ) == nil
        )
    }

    @Test("a second look click keeps the first snapshot")
    func browsingKeepsTheFirst() throws {
        var settings = custom()
        let first = look(fill: "#111111")
        let prior = KeepColorsOffer.afterClicking(
            first,
            over: settings,
            prior: nil,
            palettes: []
        )
        first.apply(to: &settings)
        let second = try #require(
            KeepColorsOffer.afterClicking(
                look(fill: "#222222"),
                over: settings,
                prior: prior,
                palettes: []
            )
        )
        #expect(second.previous == colors(custom()))
    }

    @Test("a hand edit retires the offer")
    func editRetires() throws {
        var settings = custom()
        let first = look(fill: "#111111")
        let offer = try #require(
            KeepColorsOffer.afterClicking(
                first,
                over: settings,
                prior: nil,
                palettes: []
            )
        )
        first.apply(to: &settings)
        settings.borderStyle.focusedColor = "#FEDCBA"
        #expect(!offer.shows(colors(settings)))
    }

    /// A retired offer is no run to continue: the next click
    /// snapshots the colours the user has since made.
    @Test("a click after a retirement snapshots afresh")
    func retiredOfferStartsOver() throws {
        var settings = custom()
        let first = look(fill: "#111111")
        let prior = KeepColorsOffer.afterClicking(
            first,
            over: settings,
            prior: nil,
            palettes: []
        )
        first.apply(to: &settings)
        settings.borderStyle.focusedColor = "#FEDCBA"
        let edited = colors(settings)
        let next = try #require(
            KeepColorsOffer.afterClicking(
                look(fill: "#222222"),
                over: settings,
                prior: prior,
                palettes: []
            )
        )
        #expect(next.previous == edited)
    }

    @Test("a look that changes no colour offers nothing")
    func sameColoursOfferNothing() {
        let settings = custom()
        let same = ShelfLook(
            name: "Same",
            style: [:],
            colors: colors(settings)
        )
        #expect(
            KeepColorsOffer.afterClicking(
                same,
                over: settings,
                prior: nil,
                palettes: []
            ) == nil
        )
    }

    /// A Revert returns the colours to the snapshot as well, so the
    /// verdict reads who wrote, never the colours.
    @Test("only the tick's own write survives the draft going clean")
    func cleanDraftRetiresUnlessTheTickWrote() throws {
        let offer = try #require(
            KeepColorsOffer.afterClicking(
                look(fill: "#111111"),
                over: custom(),
                prior: nil,
                palettes: []
            )
        )
        #expect(
            KeepColorsOffer.afterDraftCleaned(offer, tickWrote: true)
                == offer
        )
        #expect(
            KeepColorsOffer.afterDraftCleaned(offer, tickWrote: false)
                == nil
        )
    }
}
