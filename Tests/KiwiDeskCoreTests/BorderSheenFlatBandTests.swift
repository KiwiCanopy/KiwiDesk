import AppKit
import Testing

@testable import KiwiDeskCore

/// The sheen's contrast rule (#1644, owner 2026-09-27): the ramp's
/// FLAT band is the configured colour itself, untouched, on every
/// surface — so wherever that colour meets #578's 3:1, the band
/// does, and the focused window stays findable by it. The lifted
/// top and shaded bottom may pass the bar. The configured colours'
/// own contrast is measured where it always was
/// (`BorderRingSeparationTests`, `DragPairSeparationTests`); this
/// suite pins the SHAPE that carries it over, never a number
/// (#1021).
@Suite("Border sheen flat band (#1644)")
struct BorderSheenFlatBandTests {
    /// Every stroke the sheen paints, per bundled palette and the
    /// shipped defaults.
    private static var strokes: [(name: String, hex: String)] {
        let keys = [
            "border.focused_color", "kiwishelf.highlight_color",
            "kiwishelf.border_color", "drag.ghost.border_color",
            "drag.drop_zone.border_color",
        ]
        var out: [(String, String)] = [
            ("default ring", BorderStyle().focusedColor),
            ("default highlight", KiwiShelf().highlightColor),
            ("default border", KiwiShelf().borderColor),
        ]
        for palette in PaletteCatalog.bundled() {
            for key in keys {
                if let hex = palette.colors[key], !hex.isEmpty {
                    out.append(("\(palette.name) \(key)", hex))
                }
            }
        }
        return out
    }

    private static func rgba(_ color: NSColor) -> [Int] {
        let c = color.usingColorSpace(.sRGB) ?? color
        return [
            c.redComponent, c.greenComponent, c.blueComponent,
            c.alphaComponent,
        ].map { Int(($0 * 255).rounded()) }
    }

    /// The stops inside the flat band, read off the locations
    /// rather than assumed to be the middle two.
    private static var flatStops: [Int] {
        BorderSheen.locations.indices.filter {
            let at = BorderSheen.locations[$0]
            return at > 0 && at < 1
        }
    }

    @Test("the flat band is the configured colour on every stroke")
    func flatBandIsTheColour() {
        #expect(!PaletteCatalog.authored().isEmpty)
        #expect(Self.flatStops.count >= 2)
        for (name, hex) in Self.strokes {
            let ramp = BorderSheen.colors(hex: hex)
            let base = Self.rgba(NSColor(kiwiHex: hex))
            for stop in Self.flatStops {
                #expect(
                    Self.rgba(ramp[stop]) == base,
                    Comment(rawValue: "\(name) stop \(stop)")
                )
            }
        }
    }

    /// The ends are the sheen, at full strength: the top lifts and
    /// the bottom shades, each ruled constant untouched by any cap.
    @Test("the ends lift and shade in full")
    func endsMoveInFull() throws {
        let hex = BorderStyle().focusedColor
        let c = try #require(DragVisual.parseHex(hex))
        let l = BorderStyle.rgbToHSL(r: c.red, g: c.green, b: c.blue).2
        let ramp = BorderSheen.colors(hex: hex)
        let lightness = { (color: NSColor) -> CGFloat in
            let x = color.usingColorSpace(.sRGB) ?? color
            return BorderStyle.rgbToHSL(
                r: x.redComponent,
                g: x.greenComponent,
                b: x.blueComponent
            ).2
        }
        #expect(
            abs(lightness(ramp[0]) - (l + (1 - l) * BorderSheen.lift)) < 0.01
        )
        #expect(abs(lightness(ramp[3]) - l * BorderSheen.shade) < 0.01)
    }
}
