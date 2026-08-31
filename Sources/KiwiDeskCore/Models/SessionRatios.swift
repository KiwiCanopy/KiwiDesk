import Foundation

/// Interactive-resize values for a space with NO authored
/// override of the field (#458): writing the global visibly
/// resized every other space. Session-only — dies with the
/// space, `setMode`, or reload; config layers stay untouched
/// (#290). Precedence (authored field > session > global) is
/// structural in `TilingSettings.resolvedBsp/Stack/Scrolling`.
public struct SessionRatios: Sendable, Equatable {
    /// BSP side-by-side split (`resize("x")`).
    public var splitRatioH: Double?
    /// BSP stacked split (`resize("y")`).
    public var splitRatioV: Double?
    /// Stack master/stack split along the split axis.
    public var masterRatio: Double?
    /// Scrolling slot extent along the scroll axis.
    public var slotSize: ScrollSize?

    public init() {}
}
