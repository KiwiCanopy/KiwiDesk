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

    // MARK: - Session-aware resolution (#458)

    /// `resolvedBsp` with the space's session resize layer
    /// overlaid — authored override field > session > global —
    /// so an interactive resize on a no-override space shows on
    /// that space alone. Layout reads (`context`) and resize
    /// current-value reads use these; readers of non-ratio
    /// params may keep the id form.
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

    /// See `resolvedBsp(for: Space)`.
    public func resolvedStack(for space: Space) -> StackParams {
        var params = resolvedStack(for: space.id)
        if stack.override[space.id]?.masterRatio == nil,
            let value = space.sessionRatios.masterRatio
        {
            params.masterRatio = value
        }
        return params
    }

    /// See `resolvedBsp(for: Space)`.
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

    // MARK: - Per-space writes (interactive resize)
    //
    // Only the interactive-resize path routes here — Lua `set_*`
    // and the GUI per-space bindings write the global params or
    // the override map directly. Since #458 these write ONLY an
    // authored override field; a no-override space returns
    // false and the caller (`KiwiCore.writeSplitRatioH` family)
    // stores the value in the space's session layer instead —
    // never the global, which would visibly resize every other
    // no-override space.

    /// Writes into the space's override when it already
    /// overrides the field; returns whether it did.
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

    /// True while the Space Bar and at least one *enabled*
    /// layout App Bar resolve to the same edge (#293) — the
    /// predicate behind the Settings same-edge info row and the
    /// preview's coexistence stand-in, kept here so the two
    /// can't drift. Honors per-layout edge overrides.
    public var spaceBarSharesEdgeWithAppBar: Bool {
        guard spaceBarStyle.enabled else { return false }
        return appBarHosts.contains {
            $0.enabled
                && $0.resolved(with: appBarStyle).edge
                    == spaceBarStyle.edge
        }
    }

    /// The bar-hosting layout for a mode, or nil for modes that
    /// show no bar. **The one place that decides which layouts
    /// host an App Bar** — everything that asks "does this mode
    /// show a bar?" or "any bar shown?" derives from here, so a
    /// third hosting layout is one edit.
    ///
    /// The list had been hand-copied to three sites; a fourth
    /// hosting layout added later would have left the Settings
    /// copy claiming no bar is shown while one rendered, greying
    /// a live editor (#527). `KiwiCore.barHost(for mode:)`
    /// delegates here; its per-*space* twin necessarily keeps its
    /// own switch, because it resolves per-space params — two
    /// mirrors, which §2.4 allows, rather than three.
    public func appBarHost(
        for mode: LayoutMode
    ) -> AppBarHosting? {
        switch mode {
        case .monocle: return monocle
        case .scrolling: return scrolling
        default: return nil
        }
    }

    /// Every bar-hosting layout's per-layout bar, derived from
    /// `appBarHost(for:)` rather than re-listed.
    public var appBarHosts: [LayoutAppBar] {
        LayoutMode.allCases.compactMap {
            appBarHost(for: $0)?.appBar
        }
    }

    /// The bounds layouts may use on a display whose visible
    /// frame is `visible`: the frame minus the Space Bar's
    /// reservation (#293). The one seam between a screen's raw
    /// visible frame and `context(bounds:space:)` — every
    /// caller routes through it so no flow can silently skip
    /// the inset.
    ///
    /// Deliberately **not** `public`: it takes a raw frame the
    /// caller had to obtain some other way, so it is the
    /// unsafe half of the pair. Callers with a screen in hand
    /// want `TilingEngine.layoutBounds(on:)` (#537), and both
    /// routing guards scan only this module — a cross-module
    /// caller would be invisible to them.
    func layoutBounds(from visible: CGRect) -> CGRect {
        SpaceBarGeometry.remainingFrame(
            in: visible,
            style: spaceBarStyle
        )
    }

    /// `sticky` = the sticky window ids (#414 v2), so overflow
    /// piles can keep them fully tiled. REQUIRED so every new
    /// call site chooses (the `forceRetile` pattern, §5): a
    /// frame-producing build that silently omitted it would
    /// diverge from the applied layout only when a sticky is
    /// piled — the hardest drift to spot. Strip-geometry-only
    /// builds pass `[]` explicitly.
    ///
    /// `focusedOverride` supplies the pan anchor a focus-driven
    /// layout (Scrolling) reads, for the one case a window a space
    /// should scroll to can never be its `focused` slot: a
    /// tiled-sticky traveler is injected into the active space's
    /// row but is a member only of its home space, so the
    /// membership guard keeps `space.focused` off it (#431).
    /// Callers that carve only the bar strip omit it and fall back
    /// to `space.focused`.
    /// `screenNeighbors` carries the per-retile neighbor
    /// verdicts (#878) for the screen `bounds` describes;
    /// Scrolling reads them to wall its blocked edges. Callers
    /// that never materialize scrolled-out frames (capacity
    /// probes, bar-strip carving, previews) omit it and get the
    /// single-screen verdict — every edge open.
    public func context(
        bounds: CGRect,
        space: Space,
        sticky: Set<WindowID>,
        focusedOverride: WindowID? = nil,
        screenNeighbors: ScreenNeighbors = ScreenNeighbors()
    ) -> LayoutContext {
        LayoutContext(
            bounds: bounds,
            gaps: gaps(for: space.id),
            focused: focusedOverride ?? space.focused,
            minWindowSize: minWindowSize,
            stackWeights: space.stackWeights,
            scrollOffset: space.scrollOffset,
            trackBreaks: space.trackBreaks,
            trackWeights: space.trackWeights,
            sticky: sticky,
            screenNeighbors: screenNeighbors,
            bsp: resolvedBsp(for: space),
            stack: resolvedStack(for: space),
            scrolling: resolvedScrolling(for: space),
            grid: resolvedGrid(for: space.id),
            monocle: resolvedMonocle(for: space.id),
            track: resolvedTrack(for: space.id),
            appBarStyle: appBarStyle
        )
    }

    /// The whole settings as `space` sees them under `mode`: the
    /// active layout's params overlaid with that space's overrides,
    /// every other layout left global (they are not drawn). The
    /// per-space override editor's live preview feeds this to the
    /// SAME schematic the Layout Defaults preview draws, so the
    /// preview asks the engine rather than re-deriving a resolution
    /// rule beside the drawing (gui.md). Floating has no schematic,
    /// so it is returned untouched.
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
