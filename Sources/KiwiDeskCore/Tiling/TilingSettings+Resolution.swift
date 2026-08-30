import CoreGraphics
import Foundation

/// Per-space resolution and interactive-resize write helpers
/// (#17, #128, #458).
extension TilingSettings {
    public func gaps(for space: SpaceID) -> Gaps {
        gapsOverride[space] ?? gapsGlobal
    }

    /// Resolved scrolling parameters for space (#17).
    public func resolvedScrolling(
        for space: SpaceID
    ) -> ScrollingParams {
        (scrolling.override[space] ?? ScrollingOverride())
            .resolved(onto: scrolling)
    }

    /// Resolved BSP parameters for space (#17).
    public func resolvedBsp(for space: SpaceID) -> BspParams {
        (bsp.override[space] ?? BspOverride()).resolved(onto: bsp)
    }

    /// Resolved stack parameters for space (#17).
    public func resolvedStack(for space: SpaceID) -> StackParams {
        (stack.override[space] ?? StackOverride())
            .resolved(onto: stack)
    }

    /// Resolved grid parameters for space (#17).
    public func resolvedGrid(for space: SpaceID) -> GridParams {
        (grid.override[space] ?? GridOverride())
            .resolved(onto: grid)
    }

    /// Resolved monocle parameters for space (#17).
    public func resolvedMonocle(
        for space: SpaceID
    ) -> MonocleParams {
        (monocle.override[space] ?? MonocleOverride())
            .resolved(onto: monocle)
    }

    /// Resolved track parameters for space (#128).
    public func resolvedTrack(for space: SpaceID) -> TrackParams {
        (track.override[space] ?? TrackOverride())
            .resolved(onto: track)
    }

    /// BSP parameters with space session resize ratio layer (#458).
    public func resolvedBsp(for space: Space) -> BspParams {
        var params = resolvedBsp(for: space.id)
        let override = bsp.override[space.id]
        if override?.splitRatioH == nil,
            let value = space.sessionRatios.splitRatioH
        {
            params.splitRatioH = value
        }
        if override?.splitRatioV == nil,
            let value = space.sessionRatios.splitRatioV
        {
            params.splitRatioV = value
        }
        return params
    }

    /// Stack parameters with space session resize ratio layer (#458).
    public func resolvedStack(for space: Space) -> StackParams {
        var params = resolvedStack(for: space.id)
        if stack.override[space.id]?.masterRatio == nil,
            let value = space.sessionRatios.masterRatio
        {
            params.masterRatio = value
        }
        return params
    }

    /// Scrolling parameters with space session resize ratio layer (#458).
    public func resolvedScrolling(
        for space: Space
    ) -> ScrollingParams {
        var params = resolvedScrolling(for: space.id)
        if scrolling.override[space.id]?.slotSize == nil,
            let value = space.sessionRatios.slotSize
        {
            params.slotSize = value
        }
        return params
    }

    /// Writes splitRatioH into authored override if present (#458).
    @discardableResult
    public mutating func setSplitRatioH(
        _ value: Double,
        for space: SpaceID
    ) -> Bool {
        guard bsp.override[space]?.splitRatioH != nil else {
            return false
        }
        bsp.override[space]?.splitRatioH = value
        return true
    }

    /// Writes splitRatioV into authored override if present (#458).
    @discardableResult
    public mutating func setSplitRatioV(
        _ value: Double,
        for space: SpaceID
    ) -> Bool {
        guard bsp.override[space]?.splitRatioV != nil else {
            return false
        }
        bsp.override[space]?.splitRatioV = value
        return true
    }

    /// Writes masterRatio into authored override if present (#458).
    @discardableResult
    public mutating func setMasterRatio(
        _ value: Double,
        for space: SpaceID
    ) -> Bool {
        guard stack.override[space]?.masterRatio != nil else {
            return false
        }
        stack.override[space]?.masterRatio = value
        return true
    }

    /// Writes slotSize into authored override if present (#458).
    @discardableResult
    public mutating func setSlotSize(
        _ value: ScrollSize,
        for space: SpaceID
    ) -> Bool {
        guard scrolling.override[space]?.slotSize != nil else {
            return false
        }
        scrolling.override[space]?.slotSize = value
        return true
    }

    /// True if Space Bar and an enabled layout App Bar share an edge (#293).
    public var spaceBarSharesEdgeWithAppBar: Bool {
        guard spaceBarStyle.enabled else { return false }
        return appBarHosts.contains {
            $0.enabled
                && $0.resolved(with: appBarStyle).edge
                    == spaceBarStyle.edge
        }
    }

    /// Resolves bar hosting protocol for mode (#527).
    public func appBarHost(
        for mode: LayoutMode
    ) -> AppBarHosting? {
        switch mode {
        case .monocle: return monocle
        case .scrolling: return scrolling
        default: return nil
        }
    }

    /// Every bar-hosting layout's bar configuration.
    public var appBarHosts: [LayoutAppBar] {
        LayoutMode.allCases.compactMap {
            appBarHost(for: $0)?.appBar
        }
    }

    /// Insets visible bounds by Space Bar reservation (#293, #537).
    func layoutBounds(from visible: CGRect) -> CGRect {
        SpaceBarGeometry.remainingFrame(
            in: visible,
            style: spaceBarStyle
        )
    }

    /// Builds LayoutContext with sticky (#414 v2),
    /// overrides (#431, #881, #878), and sizeBounds (#677).
    public func context(
        bounds: CGRect,
        space: Space,
        sticky: Set<WindowID>,
        focusedOverride: WindowID? = nil,
        screenNeighbors: ScreenNeighbors = ScreenNeighbors(),
        sizeBounds: [WindowID: EffectiveSizeBound] = [:]
    ) -> LayoutContext {
        LayoutContext(
            bounds: bounds,
            gaps: gaps(for: space.id),
            focused: focusedOverride ?? space.focused,
            minWindowSize: minWindowSize,
            stackWeights: space.stackWeights,
            scrollRest: space.scrollRest,
            trackBreaks: space.trackBreaks,
            trackWeights: space.trackWeights,
            sticky: sticky,
            screenNeighbors: screenNeighbors,
            sizeBounds: sizeBounds,
            bsp: resolvedBsp(for: space),
            stack: resolvedStack(for: space),
            scrolling: resolvedScrolling(for: space),
            grid: resolvedGrid(for: space.id),
            monocle: resolvedMonocle(for: space.id),
            track: resolvedTrack(for: space.id),
            appBarStyle: appBarStyle
        )
    }

    /// Returns copy of settings with active layout mode resolved for space.
    public func resolved(
        for space: SpaceID,
        activeMode mode: LayoutMode
    ) -> TilingSettings {
        var resolved = self
        switch mode {
        case .bsp: resolved.bsp = resolvedBsp(for: space)
        case .stack: resolved.stack = resolvedStack(for: space)
        case .scrolling:
            resolved.scrolling = resolvedScrolling(for: space)
        case .grid: resolved.grid = resolvedGrid(for: space)
        case .monocle: resolved.monocle = resolvedMonocle(for: space)
        case .track: resolved.track = resolvedTrack(for: space)
        case .floating: break
        }
        return resolved
    }
}
