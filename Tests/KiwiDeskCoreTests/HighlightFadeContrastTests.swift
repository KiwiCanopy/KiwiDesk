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
/// solver's anchor ground is unexercised (guard-prover). Measured as
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
        guard let rgba = DragVisual.parseHex(hex) else { return nil }
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
        let rgba = try #require(DragVisual.parseHex(shelf.fillColor))
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
            ? KiwiShelf.idleInkFloor : KiwiShelf.readingInkFloor
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
                    #expect(
                        value >= floor - 0.01,
                        "\(palette.name) \(ink) on \(layer): \(value)"
                    )
                }
            }
        }
        #expect(measured == PaletteCatalog.bundled().count * 4)
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
