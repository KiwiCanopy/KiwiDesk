import AppKit
import Testing

@testable import KiwiDeskCore

/// The painted sheen (#1644 prototype): a lightness ramp that
/// keeps the stroke's hue and alpha, drawn only where the one
/// Liquid Glass verdict says glass draws.
@Suite("Focus ring and bar highlight sheen (#1644)")
@MainActor
struct BorderSheenTests {
    private func hsl(_ color: NSColor) -> (CGFloat, CGFloat, CGFloat) {
        let c = color.usingColorSpace(.sRGB) ?? color
        return BorderStyle.rgbToHSL(
            r: c.redComponent,
            g: c.greenComponent,
            b: c.blueComponent
        )
    }

    @Test("the top lifts, the bottom shades, the hue and alpha stay")
    func rampMovesOnlyLightness() throws {
        let hex = "#4A90E2CC"
        let ramp = BorderSheen.colors(hex: hex)
        try #require(ramp.count == BorderSheen.locations.count)
        let (h, _, l) = hsl(NSColor(kiwiHex: hex))
        let (topH, _, topL) = hsl(ramp[0])
        let (bottomH, _, bottomL) = hsl(ramp[3])
        #expect(topL > l)
        #expect(bottomL < l)
        #expect(abs(topH - h) < 1)
        #expect(abs(bottomH - h) < 1)
        for color in ramp {
            #expect(abs(color.alphaComponent - 0.8) < 0.01)
        }
    }

    @Test("the verdict follows the shelf leaf and Reduce transparency")
    func gateStandsDown() {
        let before = LiquidGlassGate.override
        defer { LiquidGlassGate.override = before }
        var shelf = KiwiShelf()
        shelf.liquidGlass = true
        LiquidGlassGate.override = { true }
        #expect(!LiquidGlassGate.drawsSheen(shelf))
        LiquidGlassGate.override = { false }
        #expect(
            LiquidGlassGate.drawsSheen(shelf)
                == AppBarStyle.glassAvailable
        )
        shelf.liquidGlass = false
        #expect(!LiquidGlassGate.drawsSheen(shelf))
    }

    @Test("the ring's geometry carries the flag to both backends")
    func geometryCarriesSheen() {
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        #expect(
            BorderGeometry.compute(
                windowFrame: frame,
                width: 4,
                cornerStyle: .rounded,
                sheen: true
            ).sheen
        )
        #expect(
            !BorderGeometry.compute(
                windowFrame: frame,
                width: 4,
                cornerStyle: .rounded
            ).sheen
        )
    }
}
