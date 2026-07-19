import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// Pins the Space Bar's two shared sizing formulas
/// (QA 2026-07-19): the item auto length's divider accounting,
/// and the one glyph/identifier font ladder the item and
/// front-app glyphs both read — the drift these were introduced
/// to prevent must itself be guarded.
@Suite("Space bar sizing math")
struct SpaceBarSizingTests {
    @Test("Auto length: identifier only, no divider")
    @MainActor
    func autoLengthEmpty() {
        // pad*2 + one identifier cell (depth - pad*2).
        #expect(
            SpaceBarItemView.autoLength(
                appCount: 0,
                depth: 32
            ) == CGFloat(8 + 24)
        )
    }

    @Test("Auto length: glyphs add the divider rule once")
    @MainActor
    func autoLengthDivider() {
        // pad*2 + identifier + (pad + 1 + pad) + 2 cells.
        #expect(
            SpaceBarItemView.autoLength(
                appCount: 2,
                depth: 32
            ) == CGFloat(8 + 24 + 9 + 48)
        )
        // The overflow badge is one more slot, same divider.
        #expect(
            SpaceBarItemView.autoLength(
                appCount: 2,
                overflow: 3,
                depth: 32
            ) == CGFloat(8 + 24 + 9 + 72)
        )
    }

    @Test("Glyph ladder: auto scales, explicit wins, clamped")
    func glyphLadder() {
        var style = SpaceBarStyle()
        // Auto: half depth, clamped to depth - 8, then ×0.9.
        #expect(
            style.glyphFontSize(forDepth: 32) == 14.4
        )
        // The identifier is the same ladder without the step.
        #expect(
            style.identifierFontSize(forDepth: 32) == 16
        )
        // Thin bar: the depth-minus-padding clamp bites.
        #expect(
            style.identifierFontSize(forDepth: 20) == 10
        )
        // Explicit font_size wins (still clamped).
        style.fontSize = 12
        #expect(
            style.glyphFontSize(forDepth: 32) == 10.8
        )
        style.fontSize = 100
        #expect(
            style.identifierFontSize(forDepth: 32) == 24
        )
    }
}
