import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// Pure frame math for the floating keyboard resize — the
/// floor, the sub-floor arms and the unbounded case. The
/// symmetric pinning against a boundary is
/// `FloatSymmetricResizeTests`, split at §2.1's ceiling rather
/// than after crossing it.
///
/// Every call here passes `bounds: nil` deliberately: with no
/// boundary neither edge can pin, so the delta always splits
/// evenly and these tests read the SIZE rules alone.
@Suite("Float resize math")
struct FloatResizeTests {
    private let base = CGRect(
        x: 40,
        y: 60,
        width: 500,
        height: 400
    )

    @Test("x grows the width from both edges; height keeps")
    func growsWidth() {
        // Symmetric since #1091: unbounded, a grow splits the
        // delta evenly and the origin moves back by half. The
        // old expectation was `origin == base.origin`, which was
        // the mouse-drag model this deliberately replaced.
        let result = FloatResize.resized(
            base,
            horizontal: true,
            delta: 150,
            minSize: 300,
            bounds: nil
        ).frame
        #expect(result.minX == base.minX - 75)
        #expect(result.width == 650)
        #expect(result.origin.y == base.origin.y)
        #expect(result.height == 400)
    }

    @Test("y shrinks the height down to min_window_size")
    func shrinkClampsAtMinSize() {
        let result = FloatResize.resized(
            base,
            horizontal: false,
            delta: -10_000,
            minSize: 300,
            bounds: nil
        ).frame
        #expect(result.height == 300)
        #expect(result.width == 500)
    }

    @Test("a sub-floor window never grows on a shrink")
    func subFloorShrinkStaysPut() {
        // Floats are never layout-clamped, so a window below
        // min_window_size is reachable; a shrink must stop
        // where it is, not jump UP to the floor.
        let small = CGRect(x: 0, y: 0, width: 100, height: 90)
        let result = FloatResize.resized(
            small,
            horizontal: true,
            delta: -10,
            minSize: 300,
            bounds: nil
        ).frame
        #expect(result.width == 100)
    }

    @Test("a sub-floor window grows by exactly the delta")
    func subFloorGrowGrowsExactly() {
        let small = CGRect(x: 0, y: 0, width: 100, height: 90)
        let result = FloatResize.resized(
            small,
            horizontal: false,
            delta: 50,
            minSize: 300,
            bounds: nil
        ).frame
        #expect(result.height == 140)
    }

    @Test("the floor never drops below 1 pt")
    func floorNeverBelowOnePoint() {
        // min_window_size accepts 0 today; AppKit rejects
        // 0-size frames, so a shrink from a normal size stops
        // at 1 pt even with no configured minimum.
        let result = FloatResize.resized(
            base,
            horizontal: true,
            delta: -10_000,
            minSize: 0,
            bounds: nil
        ).frame
        #expect(result.width == 1)
    }
}
