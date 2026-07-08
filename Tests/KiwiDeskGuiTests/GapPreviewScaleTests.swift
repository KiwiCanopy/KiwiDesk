import Foundation
import Testing

@testable import KiwiDesk

// The gap preview's real→miniature mapping (#68 §3.14): a
// sqrt curve so the everyday 0–20 pt range moves visibly
// while 60–100 pt compresses instead of blowing the 140×96
// miniature out.

@Suite("Gap preview scale")
struct GapPreviewScaleTests {
    @Test("Endpoints pin the miniature span")
    func endpoints() {
        #expect(GapPreviewScale.mini(0) == 1)
        #expect(GapPreviewScale.mini(100) == 14)
    }

    @Test("Out-of-range input clamps, never extrapolates")
    func clamps() {
        #expect(GapPreviewScale.mini(-5) == 1)
        #expect(GapPreviewScale.mini(400) == 14)
    }

    @Test("Strictly increasing across the slider range")
    func monotone() {
        var last = GapPreviewScale.mini(0)
        for real in stride(
            from: 1,
            through: 100,
            by: 1
        ) {
            let next = GapPreviewScale.mini(CGFloat(real))
            #expect(next > last)
            last = next
        }
    }

    @Test("Low range exaggerated: 0→20 moves more than 80→100")
    func lowRangeExaggerated() {
        let low =
            GapPreviewScale.mini(20) - GapPreviewScale.mini(0)
        let high =
            GapPreviewScale.mini(100)
            - GapPreviewScale.mini(80)
        #expect(low > high * 2)
    }
}
