import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// Pins the shared plate's `tab_background_fit` geometry
/// (QA 2026-07-19): hug wraps the run plus one gap per end,
/// clamped to the strip; full — and every hug fallback — spans
/// the strip.
@Suite("Bar plate fit")
struct BarPlateTests {
    private let strip = CGRect(x: 0, y: 0, width: 400, height: 32)

    @Test("Full spans the strip")
    func fullSpans() {
        #expect(
            BarPlate.frame(
                strip: strip,
                runStart: 120,
                runTotal: 100,
                inset: 0,
                gap: 6,
                horizontal: true,
                fit: .full
            ) == strip
        )
    }

    @Test("Hug wraps the run plus one gap per end")
    func hugWraps() {
        #expect(
            BarPlate.frame(
                strip: strip,
                runStart: 120,
                runTotal: 100,
                inset: 0,
                gap: 6,
                horizontal: true,
                fit: .hug
            ) == CGRect(x: 114, y: 0, width: 112, height: 32)
        )
    }

    @Test("Hug clamps to the strip's ends")
    func hugClamps() {
        #expect(
            BarPlate.frame(
                strip: strip,
                runStart: 2,
                runTotal: 396,
                inset: 0,
                gap: 6,
                horizontal: true,
                fit: .hug
            ) == CGRect(x: 0, y: 0, width: 400, height: 32)
        )
    }

    @Test("Hug falls back to full while scrolling or empty")
    func hugFallsBack() {
        // Overflowing (arrow inset reserved): nothing to hug.
        #expect(
            BarPlate.frame(
                strip: strip,
                runStart: 0,
                runTotal: 900,
                inset: 30,
                gap: 6,
                horizontal: true,
                fit: .hug
            ) == strip
        )
        // Empty run: an invisible sliver would read as a
        // vanished bar.
        #expect(
            BarPlate.frame(
                strip: strip,
                runStart: 200,
                runTotal: 0,
                inset: 0,
                gap: 6,
                horizontal: true,
                fit: .hug
            ) == strip
        )
    }

    @Test("Vertical strips hug along their long axis")
    func verticalHug() {
        let vertical = CGRect(x: 0, y: 0, width: 32, height: 400)
        #expect(
            BarPlate.frame(
                strip: vertical,
                runStart: 50,
                runTotal: 80,
                inset: 0,
                gap: 4,
                horizontal: false,
                fit: .hug
            ) == CGRect(x: 0, y: 46, width: 32, height: 88)
        )
    }
}
