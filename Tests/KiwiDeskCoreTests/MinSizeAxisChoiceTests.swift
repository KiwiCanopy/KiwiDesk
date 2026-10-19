import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// Each layout floors the axis its geometry divides (#2237). Every
/// other suite uses a square floor, under which a swapped axis is
/// invisible, so these give width and height different floors.
@Suite("Minimum window size axis choice")
struct MinSizeAxisChoiceTests {
    private let w1 = WindowID(1)
    private let w2 = WindowID(2)
    private let w3 = WindowID(3)
    private let wide = MinSize(width: 450, height: 50)

    private func context(_ floor: MinSize) -> LayoutContext {
        var context = LayoutContext(
            bounds: CGRect(x: 0, y: 0, width: 1000, height: 800),
            gaps: Gaps(),
            minWindowSize: floor
        )
        context.scrolling.appBar.enabled = false
        return context
    }

    @Test("BSP's side-by-side split keeps the width floor")
    func bspSideBySideUsesWidth() throws {
        var context = context(wide)
        context.bsp.strategy = .alternating
        context.bsp.splitRatioH = 0.1
        let frames = BspLayout().calculateGeometry(
            for: [w1, w2],
            in: context
        )
        #expect(try #require(frames[w1]).width >= 450)
    }

    @Test("Scrolling floors the axis it scrolls along")
    func scrollingUsesItsAxis() throws {
        var context = context(wide)
        context.focused = w1
        context.scrolling.slotSize = .fraction(0.05)
        let horizontal = ScrollingLayout().calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        #expect(try #require(horizontal[w1]).width == 450)
        context.minWindowSize = MinSize(width: 50, height: 450)
        context.scrolling.orientation = .vertical
        let vertical = ScrollingLayout().calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        #expect(try #require(vertical[w1]).height == 450)
    }
}
