import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A bottom-left park keeps at least `stashPeekX` on screen at a
/// fractional width, whichever whole width the app draws (#2753);
/// the bottom-right corner's x is width-free and is the control.
/// Screens at x 0 and right of it: the park x is negative on one
/// and positive on the other, which tells rounding up from
/// rounding toward zero.
@Suite("Bottom-left park peek (#2753)")
struct StashLeftPeekTests {
    static let screens = [
        CGRect(x: 0, y: 0, width: 1728, height: 1117),
        CGRect(x: 1728, y: 0, width: 1728, height: 1117),
    ]

    /// The peek a window `drawn` wide keeps on `screen` at `park`.
    private func peek(
        _ park: CGRect,
        drawn: CGFloat,
        on screen: CGRect
    ) -> CGFloat {
        park.minX + drawn - screen.minX
    }

    private func leftPark(width: CGFloat, on screen: CGRect) -> CGRect {
        TilingEngine.stashFrame(
            CGRect(x: 0, y: 0, width: width, height: 324),
            in: screen,
            corner: .bottomLeft
        )
    }

    @Test(
        "A fractional width keeps the peek at its whole width",
        arguments: screens,
        [500.25, 500.5, 500.75]
    )
    func fractionalWidthKeepsThePeek(screen: CGRect, width: CGFloat) {
        let park = leftPark(width: width, on: screen)
        #expect(park.minX == park.minX.rounded())
        for drawn in [width.rounded(.down), width.rounded(.up)] {
            let kept = peek(park, drawn: drawn, on: screen)
            #expect(kept >= TilingEngine.stashPeekX)
            #expect(kept < TilingEngine.stashPeekX + 2)
        }
        #expect(park.width == width)
    }

    @Test("A whole width parks exactly one peek in", arguments: screens)
    func wholeWidthIsUnchanged(screen: CGRect) {
        #expect(
            leftPark(width: 600, on: screen).minX
                == screen.minX + TilingEngine.stashPeekX - 600
        )
    }

    @Test("The right corner's x does not depend on the width")
    func rightCornerIsWidthFree() {
        let screen = Self.screens[0]
        let park = TilingEngine.stashFrame(
            CGRect(x: 0, y: 0, width: 500.75, height: 324),
            in: screen,
            corner: .bottomRight
        )
        #expect(park.minX == screen.maxX - TilingEngine.stashPeekX)
    }

    @Test(
        "A park at a fractional width still reads as parked",
        arguments: [500.25, 500.75]
    )
    @MainActor
    func roundedParkLooksStashed(width: CGFloat) {
        let screen = Self.screens[0]
        let park = leftPark(width: width, on: screen)
        let drawn = CGRect(
            origin: park.origin,
            size: CGSize(width: width.rounded(.down), height: 324)
        )
        #expect(TilingEngine.looksStashed(park, in: screen))
        #expect(TilingEngine.looksStashed(drawn, in: screen))
    }
}
