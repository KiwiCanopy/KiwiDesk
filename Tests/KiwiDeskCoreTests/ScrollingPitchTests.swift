import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private let w1 = WindowID(1)
private let w2 = WindowID(2)
private let w3 = WindowID(3)

/// A scrolling fraction is a share of the PITCH — window plus one
/// inner gap (#1382): `slot = f·(along + gap) − gap`, so n slots of
/// 1/n tile the axis exactly at any gap on any screen, and "50%"
/// is two windows side by side, gaps included. The press base
/// (`editablePoints`) is the same drawn slot.
@Suite("Scrolling pitch fraction (#1382)")
struct ScrollingPitchTests {
    private func context(
        fraction: Double,
        gap: CGFloat,
        focused: WindowID = w1
    ) -> LayoutContext {
        var context = LayoutContext(
            bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            gaps: .uniform(gap),
            focused: focused
        )
        context.scrolling.appBar.enabled = false
        context.scrolling.slotSize = .fraction(fraction)
        return context
    }

    @Test("1/n tiles n columns exactly, gaps included")
    func nthTilesExactly() throws {
        for (n, windows) in [(2, [w1, w2]), (3, [w1, w2, w3])] {
            for gap: CGFloat in [0, 10, 37] {
                let context = context(fraction: 1 / Double(n), gap: gap)
                let frames = ScrollingLayout().calculateGeometry(
                    for: windows,
                    in: context
                )
                let first = try #require(frames[windows.first!])
                let last = try #require(frames[windows.last!])
                #expect(abs(first.minX - context.usable.minX) < 0.01)
                #expect(abs(last.maxX - context.usable.maxX) < 0.01)
                // Each slot is the pitch share less the gap.
                let along = context.usable.width
                let expected = (along + gap) / CGFloat(n) - gap
                #expect(abs(first.width - expected) < 0.01)
            }
        }
    }

    @Test("100% is still the whole axis, and points ignore the gap")
    func edges() {
        #expect(
            ScrollSize.fraction(1)
                .resolved(along: 1000, gap: 40, horizontal: true)
                == 1000
        )
        #expect(
            ScrollSize.points(640)
                .resolved(along: 1000, gap: 40, horizontal: true)
                == 640
        )
    }

    @Test("The press base is the drawn slot")
    func pressBaseIsDrawn() throws {
        let context = context(fraction: 0.5, gap: 10)
        let drawn = try #require(
            ScrollingLayout().calculateGeometry(
                for: [w1, w2],
                in: context
            )[w1]
        )
        let base = context.scrolling.slotSize.editablePoints(
            along: context.usable.width,
            gap: 10,
            horizontal: true
        )
        #expect(abs(base - drawn.width) < 0.01)
    }
}
