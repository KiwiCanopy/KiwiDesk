import CoreGraphics
import Foundation

/// Per-space resolution and interactive-resize write helpers,
/// split from `TilingSettings` for file size (AGENTS.md §2).
extension TilingSettings {
    // MARK: - Resolution

    public func gaps(for space: SpaceID) -> Gaps {
        gapsOverride[space] ?? gapsGlobal
    }

    /// The scrolling params effective for `space` (#17): the
    /// global params with that space's optional overrides merged
    /// on top. An unoverridden space resolves an empty override,
    /// so the result always drops the per-space map (never carried
    /// into layout math) on both branches.
    public func resolvedScrolling(
        for space: SpaceID
    ) -> ScrollingParams {
        (scrolling.override[space] ?? ScrollingOverride())
            .resolved(onto: scrolling)
    }

    /// The bsp params effective for `space` (#17); see
    /// `resolvedScrolling`.
    public func resolvedBsp(for space: SpaceID) -> BspParams {
        (bsp.override[space] ?? BspOverride()).resolved(onto: bsp)
    }

    /// The stack params effective for `space` (#17); see
    /// `resolvedScrolling`.
    public func resolvedStack(for space: SpaceID) -> StackParams {
        (stack.override[space] ?? StackOverride())
            .resolved(onto: stack)
    }

    /// The grid params effective for `space` (#17); see
    /// `resolvedScrolling`.
    public func resolvedGrid(for space: SpaceID) -> GridParams {
        (grid.override[space] ?? GridOverride())
            .resolved(onto: grid)
    }

    /// The monocle params effective for `space` (#17); see
    /// `resolvedScrolling`.
    public func resolvedMonocle(
        for space: SpaceID
    ) -> MonocleParams {
        (monocle.override[space] ?? MonocleOverride())
            .resolved(onto: monocle)
    }

    /// The track params effective for `space` (#128); see
    /// `resolvedScrolling`.
    public func resolvedTrack(for space: SpaceID) -> TrackParams {
        (track.override[space] ?? TrackOverride())
            .resolved(onto: track)
    }

    // MARK: - Per-space writes (interactive resize)
    //
    // Only the interactive-resize path routes here — Lua `set_*`
    // and the GUI per-space bindings write the global params or
    // the override map directly. These helpers exist so a resize
    // edits the value the space displays without knowing whether
    // that value is overridden.

    /// Writes a resize-adjusted value for `space`: into the
    /// space's override when it already overrides that field,
    /// else into the global params. So resizing a window edits
    /// exactly the value the space currently displays — its
    /// override when it has one, the global otherwise (the
    /// pre-#17 behavior) — never silently shifting other spaces.
    public mutating func setSplitRatioH(
        _ value: Double,
        for space: SpaceID
    ) {
        if bsp.override[space]?.splitRatioH != nil {
            bsp.override[space]?.splitRatioH = value
        } else {
            bsp.splitRatioH = value
        }
    }

    public mutating func setSplitRatioV(
        _ value: Double,
        for space: SpaceID
    ) {
        if bsp.override[space]?.splitRatioV != nil {
            bsp.override[space]?.splitRatioV = value
        } else {
            bsp.splitRatioV = value
        }
    }

    public mutating func setMasterRatio(
        _ value: Double,
        for space: SpaceID
    ) {
        if stack.override[space]?.masterRatio != nil {
            stack.override[space]?.masterRatio = value
        } else {
            stack.masterRatio = value
        }
    }

    public mutating func setSlotSize(
        _ value: ScrollSize,
        for space: SpaceID
    ) {
        if scrolling.override[space]?.slotSize != nil {
            scrolling.override[space]?.slotSize = value
        } else {
            scrolling.slotSize = value
        }
    }

    /// True while the Space Bar and at least one *enabled*
    /// layout App Bar resolve to the same edge (#293) — the
    /// predicate behind the Settings same-edge info row and the
    /// preview's coexistence stand-in, kept here so the two
    /// can't drift. Honors per-layout edge overrides.
    public var spaceBarSharesEdgeWithAppBar: Bool {
        guard spaceBarStyle.enabled else { return false }
        return [monocle.appBar, scrolling.appBar].contains {
            $0.enabled
                && $0.resolved(with: appBarStyle).edge
                    == spaceBarStyle.edge
        }
    }

    /// The bounds layouts may use on a display whose visible
    /// frame is `visible`: the frame minus the Space Bar's
    /// reservation (#293). The one seam between a screen's raw
    /// visible frame and `context(bounds:space:)` — every
    /// caller routes through it so no flow can silently skip
    /// the inset.
    public func layoutBounds(from visible: CGRect) -> CGRect {
        SpaceBarGeometry.remainingFrame(
            in: visible,
            style: spaceBarStyle
        )
    }

    /// `sticky` = the sticky window ids (#414 v2), so overflow
    /// piles can keep them fully tiled; presentation-only
    /// context builds (bar geometry) may omit it.
    public func context(
        bounds: CGRect,
        space: Space,
        sticky: Set<WindowID> = []
    ) -> LayoutContext {
        LayoutContext(
            bounds: bounds,
            gaps: gaps(for: space.id),
            focused: space.focused,
            minWindowSize: minWindowSize,
            stackWeights: space.stackWeights,
            scrollOffset: space.scrollOffset,
            trackBreaks: space.trackBreaks,
            trackWeights: space.trackWeights,
            sticky: sticky,
            bsp: resolvedBsp(for: space.id),
            stack: resolvedStack(for: space.id),
            scrolling: resolvedScrolling(for: space.id),
            grid: resolvedGrid(for: space.id),
            monocle: resolvedMonocle(for: space.id),
            track: resolvedTrack(for: space.id),
            appBarStyle: appBarStyle
        )
    }
}
