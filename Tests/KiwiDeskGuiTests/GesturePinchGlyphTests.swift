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
}
