import AppKit

/// The refusal-pill door's shelf twin (#761): a bar's shortcut
/// refused draws beside the shelf it names, not on a window.
extension KiwiCore {
    /// The door's shelf twin (#761): a pill on the window side of a
    /// shelf's `strip` (AX coordinates), keyed by that shelf.
    @discardableResult
    func flashRefusalPill(
        near strip: CGRect,
        on display: DisplayID,
        edge: AppBarEdge,
        text: String,
        symbol: String,
        announce: Bool
    ) -> Bool {
        if announce { borders.announceRefusal(text) }
        return borders.flashShelfPill(
            display: display,
            edge: edge,
            frame: Self.pillRoom(beside: strip, edge: edge),
            text: text,
            symbol: symbol
        )
    }

    /// The depth of the band a shelf's pill draws in: room for the
    /// pill clear of the strip.
    static let shelfPillDepth: CGFloat = 48
    /// The narrowest band beside a vertical shelf, which is far
    /// thinner than the pill's sentence.
    static let shelfPillMinWidth: CGFloat = 320

    /// The room a shelf's pill draws in: a band on the strip's
    /// window side, its pill near the strip.
    static func pillRoom(beside strip: CGRect, edge: AppBarEdge) -> CGRect {
        let depth = shelfPillDepth
        let width = max(strip.width, shelfPillMinWidth)
        switch edge {
        case .top:
            return CGRect(
                x: strip.minX,
                y: strip.maxY,
                width: strip.width,
                height: depth
            )
        case .bottom:
            return CGRect(
                x: strip.minX,
                y: strip.minY - depth,
                width: strip.width,
                height: depth
            )
        case .left:
            return CGRect(
                x: strip.maxX,
                y: strip.minY,
                width: width,
                height: strip.height
            )
        case .right:
            return CGRect(
                x: strip.minX - width,
                y: strip.minY,
                width: width,
                height: strip.height
            )
        }
    }
}
