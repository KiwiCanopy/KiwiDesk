import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// Pure geometry of the float placement (#1674,
/// `FloatPlacement.centered`). AX coordinates throughout.
@Suite("Float placement geometry")
struct FloatPlacementTests {
    private func isCentered(_ frame: CGRect, in region: CGRect) -> Bool {
        abs(frame.midX - region.midX) < 0.001
            && abs(frame.midY - region.midY) < 0.001
    }

    @Test("A landscape region: two thirds tall, a floored third wide")
    func landscapeLaptop() {
        // A 14" MacBook's float region.
        let region = CGRect(x: 0, y: 30, width: 1718, height: 1035)
        let frame = FloatPlacement.centered(in: region)
        #expect(frame.height == 690)
        // 1718 / 3 is under the floor, and the cap is above it.
        #expect(frame.width == FloatPlacement.longFloor)
        #expect(isCentered(frame, in: region))
    }

    @Test("A short region's cap outranks the floor")
    func capOutranksFloor() {
        let region = CGRect(x: 0, y: 30, width: 1440, height: 870)
        let frame = FloatPlacement.centered(in: region)
        #expect(frame.height == 580)
        #expect(frame.width == 580 * FloatPlacement.longCap)
        #expect(frame.width < FloatPlacement.longFloor)
    }

    @Test("A wide region's long axis is capped, not a third")
    func ultrawideCap() {
        let region = CGRect(x: 0, y: 0, width: 5120, height: 1400)
        let frame = FloatPlacement.centered(in: region)
        let short = 1400 * FloatPlacement.shortShare
        #expect(abs(frame.height - short) < 0.001)
        #expect(
            abs(frame.width - short * FloatPlacement.longCap) < 0.001
        )
        #expect(frame.width < 5120 * FloatPlacement.longShare)
        #expect(isCentered(frame, in: region))
    }

    @Test("A portrait region turns the shape: wide and short")
    func portraitTurns() {
        let region = CGRect(x: 0, y: 0, width: 1440, height: 2520)
        let frame = FloatPlacement.centered(in: region)
        #expect(frame.width == 960)
        #expect(frame.height == 840)
        #expect(frame.width > frame.height)
        #expect(isCentered(frame, in: region))
    }

    @Test("A learned app minimum outranks the derived size")
    func minimumOutranks() {
        let region = CGRect(x: 0, y: 0, width: 1440, height: 870)
        let frame = FloatPlacement.centered(
            in: region,
            minimum: CGSize(width: 900, height: 700)
        )
        #expect(frame.width == 900)
        #expect(frame.height == 700)
        #expect(isCentered(frame, in: region))
    }

    @Test("A region under the floor keeps the window inside it")
    func smallRegionFits() {
        let region = CGRect(x: 100, y: 50, width: 500, height: 400)
        let frame = FloatPlacement.centered(in: region)
        #expect(region.contains(frame))
    }

    /// The one case the centring cannot fit by itself: a minimum
    /// larger than the region pins at its leading edges rather
    /// than hanging off both sides.
    @Test("A minimum past the region pins at its leading edges")
    func oversizedMinimumPins() {
        let region = CGRect(x: 100, y: 50, width: 500, height: 400)
        let frame = FloatPlacement.centered(
            in: region,
            minimum: CGSize(width: 800, height: 600)
        )
        #expect(frame.size == CGSize(width: 800, height: 600))
        #expect(frame.minX == region.minX)
        #expect(frame.minY == region.minY)
    }
}
