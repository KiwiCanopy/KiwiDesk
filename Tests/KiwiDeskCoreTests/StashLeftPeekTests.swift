import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A bottom-left park keeps at least `stashPeekX` on screen at a
/// fractional width, whichever whole width the app draws (#2753);
/// the bottom-right corner's x is width-free and is the control.
@Suite("Bottom-left park peek (#2753)")
struct StashLeftPeekTests {
    private let screen = CGRect(x: 0, y: 0, width: 1728, height: 1117)

    /// The peek a window `drawn` wide keeps on screen at `park`.
    private func peek(_ park: CGRect, drawn: CGFloat) -> CGFloat {
        park.minX + drawn - screen.minX
    }

    private func leftPark(width: CGFloat) -> CGRect {
        TilingEngine.stashFrame(
            CGRect(x: 0, y: 0, width: width, height: 324),
            in: screen,
            corner: .bottomLeft
        )
    }

    @Test(
        "A fractional width keeps the peek at its whole width",
        arguments: [500.25, 500.5, 500.75]
    )
    func fractionalWidthKeepsThePeek(width: CGFloat) {
        let park = leftPark(width: width)
        #expect(park.minX == park.minX.rounded())
        for drawn in [width.rounded(.down), width.rounded(.up)] {
            #expect(peek(park, drawn: drawn) >= TilingEngine.stashPeekX)
            #expect(
                peek(park, drawn: drawn) < TilingEngine.stashPeekX + 2
            )
        }
        #expect(park.width == width)
    }

    @Test("A whole width parks exactly one peek in")
    func wholeWidthIsUnchanged() {
        #expect(
            leftPark(width: 600).minX
                == screen.minX + TilingEngine.stashPeekX - 600
        )
    }

    @Test("The right corner's x does not depend on the width")
    func rightCornerIsWidthFree() {
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
        let park = leftPark(width: width)
        let drawn = CGRect(
            origin: park.origin,
            size: CGSize(width: width.rounded(.down), height: 324)
        )
        #expect(TilingEngine.looksStashed(park, in: screen))
        #expect(TilingEngine.looksStashed(drawn, in: screen))
    }
}
