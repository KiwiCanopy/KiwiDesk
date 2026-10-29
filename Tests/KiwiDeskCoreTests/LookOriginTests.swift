import Foundation
import Testing

@testable import KiwiDeskCore

/// The current look's origin (#1740 ▸ Step 3 decisions): a pick of a
/// look that credits someone records it beside the look settings, a
/// pick of the user's own or a bundled one clears it, and the credit
/// holds while half or more of the origin is kept.
@Suite("Look origin")
struct LookOriginTests {
    private func authored() -> ShelfLook {
        ShelfLook(
            name: "Dusk",
            style: [
                "kiwishelf.thickness": .number(30),
                "kiwishelf.corner_radius": .number(9),
            ],
            colors: ["kiwishelf.fill_color": "#112233"],
            author: "Anna"
        )
    }

    @Test("a pick of an authored look records it")
    func pickRecordsTheAuthor() {
        var settings = TilingSettings()
        authored().pick(into: &settings)
        #expect(settings.lookOrigin?.name == "Dusk")
        #expect(settings.lookOrigin?.author == "Anna")
        #expect(
            settings.lookCredit == LookCredit(name: "Dusk", author: "Anna")
        )
    }

    @Test("a pick of an own look clears the origin")
    func ownPickClears() {
        var settings = TilingSettings()
        authored().pick(into: &settings)
        ShelfLook(name: "Mine", style: [:], colors: [:])
            .pick(into: &settings)
        #expect(settings.lookOrigin == nil)
        #expect(settings.lookCredit == nil)
    }

    @Test("a plain apply leaves the origin alone")
    func applyIsNoPick() {
        var settings = TilingSettings()
        authored().pick(into: &settings)
        ShelfLook(name: "Mine", style: [:], colors: [:])
            .apply(to: &settings)
        #expect(settings.lookOrigin?.name == "Dusk")
    }

    @Test("a saved look's credit passes through its own pick")
    func keptCreditPasses() {
        let kept = LookCredit(name: "Night", author: "Maya")
        var saved = authored()
        saved.author = nil
        saved.basedOn = kept
        var settings = TilingSettings()
        saved.pick(into: &settings)
        #expect(settings.lookCredit == kept)
    }

    @Test("the credit drops below half of the origin kept")
    func creditFollowsTheShare() {
        var settings = TilingSettings()
        authored().pick(into: &settings)
        settings.kiwishelf.thickness += 4
        // One of the origin's settings changed: still half or more.
        #expect(settings.lookCredit != nil)
        var palette = ColorPaletteKeys.extract(from: settings)
        for key in palette.keys { palette[key] = "#ABCDEF" }
        ColorPalette(name: "", colors: palette).apply(to: &settings)
        #expect(settings.lookCredit == nil)
        // The origin stays: a later edit back can restore the credit.
        #expect(settings.lookOrigin?.name == "Dusk")
    }

    @Test("the origin round-trips in the settings and is absent bare")
    func originCodes() throws {
        var settings = TilingSettings()
        let encoded = try JSONEncoder().encode(settings)
        let bare =
            try JSONSerialization.jsonObject(with: encoded)
            as? [String: Any]
        #expect(bare?["look_origin"] == nil)
        authored().pick(into: &settings)
        let data = try JSONEncoder().encode(settings)
        let back = try JSONDecoder().decode(TilingSettings.self, from: data)
        #expect(back.lookOrigin == settings.lookOrigin)
        #expect(back == settings)
    }

    @Test("the shared look carries its origin to a follower")
    func sharedLookCarriesTheOrigin() {
        var settings = TilingSettings()
        authored().pick(into: &settings)
        let body = LookBody(of: settings)
        #expect(body.origin?.name == "Dusk")
        let follower = body.worn(over: TilingSettings())
        #expect(follower.lookOrigin == settings.lookOrigin)
        #expect(body.isWorn(by: follower))
        var cleared = follower
        cleared.lookOrigin = nil
        #expect(!body.isWorn(by: cleared))
    }
}
