import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The peek's count pill sizes its `macwindow` glyph from the
/// count's own font (#1946, device eyeball): the glyph draws as
/// tall as the count's cap height in every face, so a small-capped
/// script face never draws a glyph that dwarfs its number.
@Suite("Bar peek pill glyph")
@MainActor
struct BarPeekPillGlyphTests {
    private func pill(family: String) -> BarPeekPill {
        var shelf = KiwiShelf()
        shelf.fontFamily = family
        return BarPeekPill(3, shelf: shelf)
    }

    /// Two faces whose caps stand at different shares of their
    /// point size — the system font and a script face — each derive
    /// the glyph from their OWN cap height, and the drawn glyph is
    /// the derived one.
    @Test("The glyph follows the count font's cap height")
    func glyphFollowsTheCountFont() throws {
        let faces = [
            pill(family: KiwiShelf.systemFontFamily),
            pill(family: "Bradley Hand"),
        ]
        var shares: [CGFloat] = []
        for pill in faces {
            let font = try #require(pill.number.font)
            let size = BarPeekPill.glyphPointSize(for: font)
            let inkPerPoint = BarPeekBody.Metrics.pillGlyphInkPerPoint
            #expect(abs(size * inkPerPoint - font.capHeight) < 0.001)
            let expected = try #require(
                BarPeekPill.glyphImage(for: font)?.size
            )
            #expect(pill.glyph.image?.size == expected)
            shares.append(font.capHeight / font.pointSize)
        }
        // The two inputs differ on the axis the derivation reads.
        let gap = abs(shares[0] - shares[1])
        #expect(gap > 0.1)
    }

    /// The glyph's image is centred on the pill's middle, where
    /// the count's figures centre too.
    @Test("The glyph centres on the pill like the count")
    func glyphCentresOnThePill() {
        let pill = pill(family: "Bradley Hand")
        #expect(pill.glyph.frame.midY == pill.bounds.midY)
        #expect(pill.number.frame.midY == pill.bounds.midY)
    }
}
