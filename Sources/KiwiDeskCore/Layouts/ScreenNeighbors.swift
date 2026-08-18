import CoreGraphics

/// Which edges of a screen have another connected screen beyond
/// them (#878). Scrolling picks its per-edge clamp form from
/// this: past an *open* edge a scrolled-out slot may overhang
/// into the void, but past a *blocked* edge it must stop fully
/// on its own screen — the "offscreen" region there is the
/// neighbor screen, frames are global, and macOS cannot clip or
/// hide another app's window, so an overhang would render on
/// the neighbor. Monocle's `park` hide style consumes the
/// left/right pair the same way, through
/// `TilingEngine.optimalHideCorner(neighbors:)` (#881).
///
/// The flags are an input to the retile, never a cache: the
/// engine detects them fresh from the connected screens on
/// every `layoutInput` (#878), and a screen plugged in or out
/// is picked up by the retile that `displaysChanged` already
/// triggers, so they cannot go stale.
public struct ScreenNeighbors: Sendable, Equatable {
    public var left: Bool
    public var right: Bool
    public var top: Bool
    public var bottom: Bool

    public init(
        left: Bool = false,
        right: Bool = false,
        top: Bool = false,
        bottom: Bool = false
    ) {
        self.left = left
        self.right = right
        self.top = top
        self.bottom = bottom
    }

    /// The verdicts for `screen` among `others` — the stash's
    /// #410 corner scan generalized to all four edges
    /// (`optimalHideCorner` consumes the left/right pair). A
    /// neighbor is any other screen wholly at or past the edge,
    /// overlapping the edge's own span; the 1 pt slack absorbs
    /// the insets (menu bar, Dock) that keep visible frames
    /// from touching exactly. All rects are AX visible frames:
    /// x is shared with Cocoa and y grows downward, so `bottom`
    /// means below in physical terms. `screen` itself can never
    /// lie past its own edge, so callers may pass the full
    /// screen list unfiltered.
    public static func detect(
        around screen: CGRect,
        among others: [CGRect]
    ) -> ScreenNeighbors {
        func overlapsY(_ other: CGRect) -> Bool {
            other.minY < screen.maxY && other.maxY > screen.minY
        }
        func overlapsX(_ other: CGRect) -> Bool {
            other.minX < screen.maxX && other.maxX > screen.minX
        }
        var found = ScreenNeighbors()
        for other in others {
            if other.maxX <= screen.minX + 1, overlapsY(other) {
                found.left = true
            }
            if other.minX >= screen.maxX - 1, overlapsY(other) {
                found.right = true
            }
            if other.maxY <= screen.minY + 1, overlapsX(other) {
                found.top = true
            }
            if other.minY >= screen.maxY - 1, overlapsX(other) {
                found.bottom = true
            }
        }
        return found
    }
}
