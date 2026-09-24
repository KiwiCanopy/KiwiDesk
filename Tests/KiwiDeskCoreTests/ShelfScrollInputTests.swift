import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// Every scroll device moves a shelf section along its one axis
/// (#1517).
@Suite("Shelf scroll input")
struct ShelfScrollInputTests {
    private func travel(
        _ x: CGFloat,
        _ y: CGFloat,
        precise: Bool = false
    ) -> CGFloat {
        ShelfScrollInput.travel(
            .init(x: x, y: y, precise: precise),
            itemStep: 40
        )
    }

    @Test("A wheel notch moves about one item, either wheel axis")
    func wheelNotch() {
        // Wheel down (negative y) moves toward the end.
        #expect(travel(0, -1) == 40)
        #expect(travel(0, 1) == -40)
        // Tilt and shift-wheel arrive as x.
        #expect(travel(-1, 0) == 40)
    }

    @Test("A trackpad moves by its points on the dominant axis")
    func trackpadPoints() {
        #expect(travel(-12, 3, precise: true) == 12)
        #expect(travel(2, -30, precise: true) == 30)
    }

    /// `scrollingDelta` already carries the user's natural
    /// scrolling choice; mapping it once must not invert it: the
    /// same physical swipe under both settings arrives with
    /// opposite signs and must travel opposite ways.
    @Test("Natural scrolling is honoured, never flipped twice")
    func naturalScrollingPassesThrough() {
        let natural = travel(0, 20, precise: true)
        let classic = travel(0, -20, precise: true)
        #expect(natural == -classic)
        #expect(natural == -20)
    }

    @Test("No movement, no travel")
    func still() {
        #expect(travel(0, 0) == 0)
    }
}
