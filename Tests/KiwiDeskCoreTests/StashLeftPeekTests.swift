import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A bottom-left park leaves at least `stashPeekX` on screen for
/// a fractional width (#2753). A stack slot is `500.25` wide, the
/// app draws the window a whole `500`, and a park measured from
/// the asked width left 0.75 pt — under which macOS pulled the
/// window back to its 40 pt floor on device. The bottom-right
/// corner's x is width-free and is the control.
@Suite("Bottom-left park peek (#2753)")
struct StashLeftPeekTests {
    private let screen = CGRect(x: 0, y: 0, width: 1728, height: 1117)

    /// The peek a window `drawn` wide keeps on screen at `park`.
    private func peek(_ park: CGRect, drawn: CGFloat) -> CGFloat {
        park.minX + drawn - screen.minX
    }

    @Test("A fractional width keeps the peek at its whole width")
    func fractionalWidthKeepsThePeek() {
        let frame = CGRect(x: 0, y: 0, width: 500.25, height: 324)
        let park = TilingEngine.stashFrame(
            frame,
            in: screen,
            corner: .bottomLeft
        )
        #expect(park.minX == park.minX.rounded())
        #expect(peek(park, drawn: 500) >= TilingEngine.stashPeekX)
        #expect(peek(park, drawn: 500) < TilingEngine.stashPeekX + 1)
        #expect(park.size == frame.size)
    }

    @Test("A whole width parks exactly one peek in")
    func wholeWidthIsUnchanged() {
        let frame = CGRect(x: 0, y: 0, width: 600, height: 400)
        let park = TilingEngine.stashFrame(
            frame,
            in: screen,
            corner: .bottomLeft
        )
        #expect(
            park.minX == screen.minX + TilingEngine.stashPeekX - 600
        )
    }

    @Test("The right corner's x does not depend on the width")
    func rightCornerIsWidthFree() {
        let frame = CGRect(x: 0, y: 0, width: 500.25, height: 324)
        let park = TilingEngine.stashFrame(
            frame,
            in: screen,
            corner: .bottomRight
        )
        #expect(park.minX == screen.maxX - TilingEngine.stashPeekX)
    }

    @Test("A park at a fractional width still reads as parked")
    @MainActor
    func roundedParkLooksStashed() {
        let frame = CGRect(x: 0, y: 0, width: 500.25, height: 324)
        let park = TilingEngine.stashFrame(
            frame,
            in: screen,
            corner: .bottomLeft
        )
        let drawn = CGRect(
            origin: park.origin,
            size: CGSize(width: 500, height: 324)
        )
        #expect(TilingEngine.looksStashed(drawn, in: screen))
    }

    @Test("Monocle's left park takes the rounded x")
    func monocleParkIsRounded() {
        // A layout parking through the shared corner gets the
        // fix; a fractional usable width is the stack slot's
        // shape in the monocle slot.
        var context = LayoutContext(
            bounds: CGRect(x: 0, y: 0, width: 1000.5, height: 800),
            gaps: .uniform(10)
        )
        context.monocle.appBar.visibility = .hidden
        context.monocle.hideStyle = .park
        context.focused = WindowID(1)
        context.screenNeighbors = ScreenNeighbors(right: true)
        let frames = MonocleLayout().calculateGeometry(
            for: [WindowID(1), WindowID(2)],
            in: context
        )
        let parked = frames[WindowID(2)]
        #expect(parked != nil)
        guard let parked else { return }
        #expect(parked.width != parked.width.rounded())
        #expect(parked.minX == parked.minX.rounded())
        #expect(
            parked.minX + parked.width.rounded(.down)
                >= context.bounds.minX + TilingEngine.stashPeekX
        )
    }
}
