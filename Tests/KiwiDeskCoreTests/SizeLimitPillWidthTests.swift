import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The size pill's second, silent decline (#1255, ui-designer
/// 2026-09-05).
///
/// `flashSizeLimitPill` reported `true` the moment the private
/// runtime was up, but the overlay declines again on a window
/// too narrow to hold a pill — so a refusal on a narrow frame
/// sounded while nothing appeared, which is exactly the
/// audible-but-invisible defect #1255 removed. The seam guard
/// cannot see it: it pins that the sound follows the DRAWING's
/// verdict, not that the drawing tells the truth.
///
/// Pinned here as arithmetic rather than through the overlay,
/// which needs a screen (tests.md ▸ reach the machine only
/// through injected seams).
@Suite("Size limit pill width")
struct SizeLimitPillWidthTests {
    private func frame(width: CGFloat) -> CGRect {
        CGRect(x: 0, y: 0, width: width, height: 400)
    }

    @Test("a window too narrow to hold a pill declines")
    func narrowWindowDeclines() {
        #expect(
            SizeLimitOverlay.pillWidth(
                frame: frame(width: 60),
                textWidth: 200
            ) == nil
        )
    }

    /// The boundary is read off the arithmetic rather than
    /// restated: the pill is capped at the frame minus its
    /// inset, so the narrowest drawable window is whatever
    /// makes that cap exceed the floor.
    @Test("the decline is a boundary, not a blanket refusal")
    func boundaryIsCrossable() {
        var narrowest: CGFloat?
        for width in stride(from: 40.0, through: 200.0, by: 1) {
            if SizeLimitOverlay.pillWidth(
                frame: frame(width: width),
                textWidth: 200
            ) != nil {
                narrowest = width
                break
            }
        }
        let found = narrowest ?? 0
        #expect(found > 40)
        #expect(
            SizeLimitOverlay.pillWidth(
                frame: frame(width: found - 1),
                textWidth: 200
            ) == nil
        )
    }

    /// A wide window draws, and long text widens the pill
    /// rather than being swallowed — the cap is the FRAME's,
    /// never the text's.
    @Test("a drawable window reports its width")
    func wideWindowDraws() throws {
        let narrow = try #require(
            SizeLimitOverlay.pillWidth(
                frame: frame(width: 900),
                textWidth: 40
            )
        )
        let wide = try #require(
            SizeLimitOverlay.pillWidth(
                frame: frame(width: 900),
                textWidth: 400
            )
        )
        #expect(wide > narrow)
        // …and neither may exceed what the frame allows.
        #expect(wide <= 900 - 24)
    }
}
