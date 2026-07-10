import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// Pure frame math for the floating keyboard resize.
@Suite("Float resize math")
struct FloatResizeTests {
    private let base = CGRect(
        x: 40,
        y: 60,
        width: 500,
        height: 400
    )

    @Test("x grows the width; origin and height keep")
    func growsWidth() {
        let result = FloatResize.resized(
            base,
            horizontal: true,
            delta: 150,
            minSize: 300
        )
        #expect(result.origin == base.origin)
        #expect(result.width == 650)
        #expect(result.height == 400)
    }

    @Test("y shrinks the height down to min_window_size")
    func shrinkClampsAtMinSize() {
        let result = FloatResize.resized(
            base,
            horizontal: false,
            delta: -10_000,
            minSize: 300
        )
        #expect(result.height == 300)
        #expect(result.width == 500)
    }

    @Test("the floor never drops below 1 pt")
    func floorNeverBelowOnePoint() {
        // min_window_size accepts 0 today; a 0-size frame
        // would be rejected by AppKit and could not be grown
        // back, so the floor holds at 1 pt regardless.
        let result = FloatResize.resized(
            base,
            horizontal: true,
            delta: -10_000,
            minSize: 0
        )
        #expect(result.width == 1)
    }
}
