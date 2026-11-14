import AppKit
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The spread and pinch inputs' icons (#1873 ▸ Ruling amendment
/// 2026-11-13, owner): arrows drawn as `CustomGlyph`s, no hand and no
/// finger count, and each of the four draws its own picture — on the
/// macOS 14 floor the two pinches once shared one stand-in.
/// Renders four 20 pt template images on the main actor.
@MainActor
@Suite("Gesture pinch glyphs")
struct GesturePinchGlyphTests {
    static let inputs: [GestureInput] = [
        .spread, .pinchTogether, .spread4, .pinchTogether4,
    ]

    @Test("each spread and pinch is a drawn glyph of its own")
    func fourGlyphs() throws {
        var pictures: [Data] = []
        for input in Self.inputs {
            let name = GestureListWords.symbol(input)
            let glyph = try #require(
                CustomGlyph(name: name),
                "\(input) wears \(name), not a drawn glyph"
            )
            let bitmap = try #require(
                glyph.image.tiffRepresentation,
                "\(name) drew nothing"
            )
            pictures.append(bitmap)
        }
        #expect(Set(pictures).count == Self.inputs.count)
    }

    /// The two-finger pair runs on the rising diagonal, never the
    /// falling one Toggle Maximize's symbol takes (#1873 ▸ 2026-11-14).
    /// Read at a fixed 2x, alpha over a half (pixel probes).
    @Test("the two-finger pair rises to the top right")
    func twoFingersRise() throws {
        for glyph in [CustomGlyph.spread(2), .pinch(2)] {
            let corners = try Self.inkedCorners(glyph.image)
            #expect(corners.topRight, "\(glyph.name)")
            #expect(corners.bottomLeft, "\(glyph.name)")
            #expect(!corners.topLeft, "\(glyph.name)")
            #expect(!corners.bottomRight, "\(glyph.name)")
        }
    }

    /// Whether any pixel in each 8 pt corner square is inked.
    private static func inkedCorners(
        _ image: NSImage
    ) throws -> (
        topLeft: Bool, topRight: Bool, bottomLeft: Bool, bottomRight: Bool
    ) {
        let side = 40
        let rep = try #require(
            NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: side,
                pixelsHigh: side,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        )
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
        NSGraphicsContext.restoreGraphicsState()
        // colorAt's y counts from the top.
        func inked(_ xs: Range<Int>, _ ys: Range<Int>) -> Bool {
            xs.contains { x in
                ys.contains { y in
                    (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.5
                }
            }
        }
        let low = 0..<16
        let high = 24..<side
        return (
            inked(low, low), inked(high, low),
            inked(low, high), inked(high, high)
        )
    }
}
