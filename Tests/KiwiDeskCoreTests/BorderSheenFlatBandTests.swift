import AppKit
import Testing

@testable import KiwiDeskCore

/// The sheen's contrast rule (#1644, owner 2026-09-27): the ramp's
/// FLAT band is the configured colour itself, untouched, on every
/// surface — so wherever that colour meets #578's 3:1, the band
/// does, and the focused window stays findable by it. Only the
/// lifted top may pass the bar; the band runs to the bottom. The
/// configured colours' own contrast is measured where it always was
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

    /// The stops inside the flat band — every one below the lifted
    /// top, the bottom included — read off the locations.
    private static var flatStops: [Int] {
        BorderSheen.locations.indices.filter {
            BorderSheen.locations[$0] > 0
        }
    }

    @Test("the flat band is the configured colour on every stroke")
    func flatBandIsTheColour() {
        #expect(!PaletteCatalog.authored().isEmpty)
        #expect(Self.flatStops.count >= 2)
        for (name, hex) in Self.strokes {
            let base = Self.rgba(NSColor(kiwiHex: hex))
            for strength: CGFloat in [1, 0.5, -0.5, -1] {
                let ramp = BorderSheen.colors(hex: hex, strength: strength)
                for stop in Self.flatStops {
                    #expect(
                        Self.rgba(ramp[stop]) == base,
                        Comment(
                            rawValue: "\(name) at \(strength) stop \(stop)"
                        )
                    )
                }
            }
        }
    }
}
