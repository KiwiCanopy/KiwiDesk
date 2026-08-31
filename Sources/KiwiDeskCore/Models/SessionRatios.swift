import Foundation

/// Interactive-resize session overrides without persisting to config
/// (#290, #458).
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
