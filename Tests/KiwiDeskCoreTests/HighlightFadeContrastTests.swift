import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// KiwiHub's selection and hover fade to `highlightFadeShare`
/// (`KiwiHubPaint.fill`): at the fade's far end the selected item's
/// ink on the faded highlight, and the hovered item's on the faded
/// hover, hold the reading floor over the panel's own far end, on
/// every bundled palette, Fill fade at 100. Residue: no bundled
/// palette's share is decided at the panel's anchor end, so the
/// solver's anchor ground is unexercised (guard-prover), and none's is
/// decided by the filled-row lift over the black wallpaper, so that
/// arm of `liftSeparates` is unexercised too (#3264). Measured as
/// `PeekInkContrastTests` measures: each layer composited over each
/// wallpaper extreme, the ink over the layer.
@Suite("KiwiHub highlight fade contrast")
struct HighlightFadeContrastTests {
    private static let wallpapers = ["#FFFFFF", "#000000"]

    /// The shelf a bundled palette paints, at the strongest fade.
    private func painted(_ palette: ColorPalette) -> KiwiShelf {
        var settings = TilingSettings()
        palette.apply(to: &settings)
        var shelf = settings.kiwishelf
        shelf.fillFade = 100
        return shelf
    }

    /// `hex` with its alpha scaled by `share`.
    private func scaled(_ hex: String, by share: CGFloat) -> String? {
        guard let rgba = HexColor.parse(hex) else { return nil }
        let bytes = [rgba.red, rgba.green, rgba.blue, rgba.alpha * share]
            .map { String(format: "%02X", Int(($0 * 255).rounded())) }
        return "#" + bytes.joined()
    }

    /// The worst contrast of `ink` on `layer` at `share` over the
    /// panel's far end over either wallpaper.
    private func worst(
        _ ink: String,
        on layer: String,
        at share: CGFloat,
        ground: String
    ) throws -> Double {
        let faded = try #require(scaled(layer, by: share))
        var worst = Double.infinity
        for wallpaper in Self.wallpapers {
            let plate = try #require(
                ColorVision.composite(ground, over: wallpaper)
            )
            let under = try #require(
                ColorVision.composite(faded, over: plate)
            )
            let top = try #require(ColorVision.composite(ink, over: under))
            worst = min(worst, try #require(ColorVision.contrast(top, under)))
        }
        return worst
    }

    /// The panel's two ends — the anchor at the cap, the far end
    /// at the panel's own share, mirroring `GlassTint.rendered` —
    /// and the share KiwiHub's fills fade to; a fill fades over its
    /// own row, so it may sit on either.
    private func ends(
        _ shelf: KiwiShelf,
        increaseContrast: Bool
    ) throws -> (grounds: [String], share: CGFloat) {
        let fill = shelf.panelGlassFill(increaseContrast: increaseContrast)
        let rgba = try #require(HexColor.parse(shelf.fillColor))
        let anchor = min(CGFloat(rgba.alpha), GlassTint.maxAlpha)
        let far = max(GlassTint.farShare(fade: fill.fade), fill.minShare)
        let alpha = CGFloat(rgba.alpha)
        let grounds = try [anchor, anchor * far].map {
            try #require(scaled(shelf.fillColor, by: $0 / alpha))
        }
        return (
            grounds,
            shelf.highlightFadeShare(increaseContrast: increaseContrast)
        )
    }

    @Test(
        "A faded selection and hover hold the floor on every palette",
        arguments: [false, true]
    )
    func fadedInksHoldTheFloor(increaseContrast: Bool) throws {
        let floor =
            increaseContrast
            ? KiwiShelf.increasedReadingInkFloor : KiwiShelf.readingInkFloor
        var measured = 0
        for palette in PaletteCatalog.bundled() {
            let shelf = painted(palette)
            let paint = shelf.panelHighlight
            let (grounds, share) = try ends(
                shelf,
                increaseContrast: increaseContrast
            )
            for ground in grounds {
                for (ink, layer) in [
                    (paint.selectionInk, paint.selection),
                    (paint.hoverInk, paint.hover),
                ] {
                    let value = try worst(
                        ink,
                        on: layer,
                        at: share,
                        ground: ground
                    )
                    measured += 1
                    // A fill whose ink misses the floor even unfaded
                    // stays whole: nothing fades.
                    #expect(
                        value >= floor - 0.01 || share == 1,
                        "\(palette.name) \(ink) on \(layer): \(value)"
                    )
                }
            }
        }
        #expect(measured == PaletteCatalog.bundled().count * 4)
    }

    /// The separation of `lift` over `layer` at `share` from the layer
    /// alone, the worst over either wallpaper.
    private func liftSeparation(
        _ lift: String,
        over layer: String,
        at share: CGFloat,
        ground: String
    ) throws -> Double {
        let row = try #require(scaled(layer, by: share))
        var worst = Double.infinity
        for wallpaper in Self.wallpapers {
            let plate = try #require(
                ColorVision.composite(ground, over: wallpaper)
            )
            let under = try #require(ColorVision.composite(row, over: plate))
            let lifted = try #require(ColorVision.composite(lift, over: under))
            worst = min(
                worst,
                try #require(ColorVision.separation(lifted, under))
            )
        }
        return worst
    }

    /// A tile's hover on a filled row lifts in the row's selection ink
    /// by the ink's polarity (#3264 ▸ Ruling amendment): at the solved
    /// share it separates from the fill on every bundled palette, and
    /// the share is the smallest at which it and the inks hold.
    @Test(
        "A hover on a filled row separates at the solved share",
        arguments: [false, true]
    )
    func filledRowLiftSeparates(increaseContrast: Bool) throws {
        let floor =
            increaseContrast
            ? KiwiShelf.increasedReadingInkFloor : KiwiShelf.readingInkFloor
        var measured = 0
        var raised = 0
        for palette in PaletteCatalog.bundled() {
            let shelf = painted(palette)
            let paint = shelf.panelHighlight
            let (grounds, share) = try ends(
                shelf,
                increaseContrast: increaseContrast
            )
            let lift = try #require(
                scaled(
                    paint.selectionInk,
                    by: KiwiShelf.filledRowLift(ink: paint.selectionInk)
                )
            )
            // Slack reads rounding at the solved share; below it the
            // solver's own thresholds decide.
            func separates(_ at: CGFloat, give: Double) throws -> Bool {
                try grounds.allSatisfy { ground in
                    try liftSeparation(
                        lift,
                        over: paint.selection,
                        at: at,
                        ground: ground
                    ) >= ColorVision.separationFloor - give
                }
            }
            func reads(_ at: CGFloat, give: Double) throws -> Bool {
                try grounds.allSatisfy { ground in
                    try [
                        (paint.selectionInk, paint.selection),
                        (paint.hoverInk, paint.hover),
                    ].allSatisfy { ink, layer in
                        try worst(ink, on: layer, at: at, ground: ground)
                            >= floor - give
                    }
                }
            }
            measured += 1
            // Every bundled palette's lift holds at its share; an ink
            // that misses even unfaded stays whole, as above.
            #expect(
                try separates(share, give: 0.5),
                "\(palette.name) lift misses at \(share)"
            )
            let base = max(
                GlassTint.farShare(fade: shelf.fillFade),
                KiwiShelf.highlightFloorShare
            )
            if share > base + 0.01 {
                raised += 1
                let below = share - 0.01
                #expect(
                    try !(separates(below, give: 0) && reads(below, give: 0)),
                    "\(palette.name) holds below \(share)"
                )
            }
        }
        #expect(measured == PaletteCatalog.bundled().count)
        // Some share solves above its base, so minimality is asked.
        #expect(raised > 0)
    }

    /// The floor is a floor and not a pin: under Increase Contrast,
    /// 0.4 sinks some bundled palette's ink below the stricter
    /// floor, and the share rises past it to hold.
    @Test("Increase Contrast lifts some palette's share")
    func increasedContrastLifts() throws {
        var lifted = 0
        for palette in PaletteCatalog.bundled() {
            let shelf = painted(palette)
            let normal = shelf.highlightFadeShare(increaseContrast: false)
            let raised = shelf.highlightFadeShare(increaseContrast: true)
            #expect(raised >= normal, "\(palette.name)")
            if raised > normal { lifted += 1 }
        }
        #expect(lifted > 0)
    }
}
