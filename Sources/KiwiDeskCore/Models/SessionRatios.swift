import Foundation

/// Interactive-resize values for a space that has NO authored
/// config override of the field (#458). Before this layer, a
/// resize on such a space wrote the GLOBAL ratio, visibly
/// resizing every other no-override space (obvious with two
/// monitors showing two spaces). Session-only, like
/// `stackWeights`: config layers stay untouched — the #290
/// override editor never fills with overrides the user did not
/// author — and the value dies with the space, an actual mode
/// change (`setMode`), or a config reload.
///
/// Read precedence is enforced structurally in
/// `TilingSettings.resolvedBsp/Stack/Scrolling(for: Space)`:
/// authored override field > session value > global. A space
/// whose override carries the field routes interactive writes
/// into that override (pre-#458 behavior), so its session slot
/// stays empty. Known edge, accepted: removing an override
/// field mid-session can resurface an older session value
/// until the next mode change or reload.
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
