import CoreGraphics
import Foundation

/// Per-space resolution (#17, #128) and the session-layer overlay
/// an interactive resize reads through (#458, #764).
extension TilingSettings {
    public func gaps(for space: SpaceID) -> Gaps {
        gapsOverride[space] ?? gapsGlobal
    }

    /// Resolved scrolling parameters for space (#17) — config
    /// only, like `resolvedBsp(for: SpaceID)`.
    public func resolvedScrolling(
        for space: SpaceID
    ) -> ScrollingParams {
        (scrolling.override[space] ?? ScrollingOverride())
            .resolved(onto: scrolling)
    }

    /// Resolved BSP parameters for space (#17) — config only: a
    /// size a resize moves is read through the `Space` overload.
    public func resolvedBsp(for space: SpaceID) -> BspParams {
        (bsp.override[space] ?? BspOverride()).resolved(onto: bsp)
    }

    /// Resolved stack parameters for space (#17) — config only,
    /// like `resolvedBsp(for: SpaceID)`.
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

    /// BSP parameters under the session layer, which outranks the
    /// authored override (#458, #764).
    public func resolvedBsp(for space: Space) -> BspParams {
        var params = resolvedBsp(for: space.id)
        if let value = space.sessionRatios.splitRatioH {
            params.splitRatioH = value
        }
        if let value = space.sessionRatios.splitRatioV {
            params.splitRatioV = value
        }
        return params
    }

    /// Stack parameters under the session layer (#458, #764).
    public func resolvedStack(for space: Space) -> StackParams {
        var params = resolvedStack(for: space.id)
        if let value = space.sessionRatios.masterRatio {
            params.masterRatio = value
        }
        return params
    }

    /// Scrolling parameters under the session layer (#458, #764).
    public func resolvedScrolling(
        for space: Space
    ) -> ScrollingParams {
        var params = resolvedScrolling(for: space.id)
        if let value = space.sessionRatios.slotSize {
            params.slotSize = value
        }
        return params
    }

    /// Whether the KiwiShelf carries any bar in some layout — the
    /// Space Bar or any layout's App Bar is on. The Settings gates
    /// ask it; the reservation asks `shelfShows(in:)`.
    public var shelfShows: Bool {
        spaceBarStyle.enabled || anyAppBarCanShow
    }

    /// Whether a bar draws on the shelf of a space laid out in
    /// `mode` — the Space Bar, which draws in every layout, or
    /// that layout's own App Bar — and so whether the strip is
    /// reserved there (#1517). A layout that draws no bar keeps
    /// the whole screen; the price is that with the Space Bar off,
    /// a switch into a layout whose App Bar shows moves windows
    /// by the strip.
    public func shelfShows(in mode: LayoutMode) -> Bool {
        spaceBarStyle.enabled
            || appBarHost(for: mode)?.appBar.enabled == true
    }

    /// True if any layout's App Bar is switched on.
    public var anyAppBarCanShow: Bool {
        appBarHosts.contains { $0.enabled }
    }

    /// True if the Space Bar and a layout's App Bar can both show,
    /// splitting the shelf between them (`ShelfArrangement`).
    public var bothBarsCanShow: Bool {
        spaceBarStyle.enabled && anyAppBarCanShow
    }

    /// What the Space Bar draws from: the shelf and its own style.
    public var spaceBarLook: SpaceBarLook {
        SpaceBarLook(shelf: kiwishelf, bar: spaceBarStyle)
    }

    /// The shelf and the App Bar's global style, before any
    /// layout's overrides — what `AppBarHosting.resolvedBar`
    /// resolves from.
    public var appBarGlobalLook: AppBarLook {
        AppBarLook(shelf: kiwishelf, bar: appBarStyle)
    }

    /// What a layout's App Bar draws from: the shelf and the App
    /// Bar's style after that layout's overrides — the one body,
    /// which `AppBarHosting.resolvedBar` calls too.
    public func appBarLook(for bar: LayoutAppBar) -> AppBarLook {
        bar.look(on: appBarGlobalLook)
    }

    /// The bar-hosting layout for a mode — the ONE place that
    /// decides which layouts host an App Bar (#527): everything
    /// asking "does this mode show a bar?" derives from here, so
    /// a third hosting layout is one edit. `KiwiCore`'s per-space
    /// twin keeps its own switch by necessity — two mirrors, which
    /// §2.4 allows, never three.
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

    /// Insets visible bounds by the shelf's reservation wherever a
    /// bar draws in `mode` (#293, #1517).
    /// Deliberately NOT public: it takes a raw frame the caller
    /// obtained some other way — the unsafe half. Callers with a
    /// screen want `TilingEngine.layoutBounds(on:)` (#537), and
    /// the routing guards scan only this module, so a cross-module
    /// caller would be invisible to them.
    func layoutBounds(
        from visible: CGRect,
        mode: LayoutMode
    ) -> CGRect {
        guard shelfShows(in: mode) else { return visible }
        return ShelfGeometry.remainingFrame(
            in: visible,
            shelf: kiwishelf
        )
    }

    /// The most scrolling slots that fit `bounds` — the layout
    /// region `KiwiCore.scrollingColumnCap` hands in — for
    /// `space` (its resolved gaps, bars and orientation; nil
    /// resolves the globals, the Layout Defaults card). The
    /// Settings stepper's ▲ bound (#1382), derived from the terms
    /// `ScrollingLayout.metrics` draws with and never from GUI
    /// arithmetic over a screen frame (`ScrollingColumnCapTests`).
    func scrollingColumnCap(
        bounds: CGRect,
        space: SpaceID?
    ) -> Int {
        let gaps = space.map(gaps(for:)) ?? gapsGlobal
        let params = space.map(resolvedScrolling(for:)) ?? scrolling
        let area = LayoutContext.usable(bounds, outer: gaps.outer)
        let horizontal = params.axisIsHorizontal
        return ScrollSize.maxCount(
            along: horizontal ? area.width : area.height,
            gap: horizontal ? gaps.inner.horizontal : gaps.inner.vertical,
            minimum: minWindowSize
        )
    }

    /// Builds a LayoutContext. `sticky` (#414 v2) is REQUIRED so every call
    /// site chooses (the `forceRetile` pattern, §5): a
    /// frame-producing build that silently omitted it would
    /// diverge only when a sticky is piled — the hardest drift to
    /// spot; strip-geometry builds pass `[]` explicitly.
    /// `focusedOverride` (#431), `screenNeighbors` (#878, #881)
    /// and `sizeBounds` (#677) follow the same choose-or-omit
    /// shape.
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
            track: resolvedTrack(for: space.id)
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
