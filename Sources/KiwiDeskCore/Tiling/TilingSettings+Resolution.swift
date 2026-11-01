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

    /// Stack parameters under the session layer (#458, #764) and
    /// the side the Space draws on the Desktop shown now (#2771):
    /// `flip` is `KiwiCore.stackFlip(of:)`'s answer, required so
    /// every reader of the drawn side takes the one door.
    public func resolvedStack(
        for space: Space,
        flip: StackParams.StackPosition?
    ) -> StackParams {
        var params = resolvedStack(for: space.id)
        if let value = space.sessionRatios.masterRatio {
            params.masterRatio = value
        }
        if let flip { params.stackPosition = flip }
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

    /// Grid parameters under the session layer (#763, #764).
    public func resolvedGrid(for space: Space) -> GridParams {
        var params = resolvedGrid(for: space.id)
        if let value = space.sessionRatios.gridColumnWeights {
            params.columnWeights = value
        }
        if let value = space.sessionRatios.gridRowWeights {
            params.rowWeights = value
        }
        return params
    }

    /// True if any layout's App Bar shows without its shortcut —
    /// `always` or `auto` (#761).
    public var anyAppBarCanShow: Bool {
        appBarHosts.contains { $0.visibility.showsUnprompted }
    }

    /// True if the Space Bar and a layout's App Bar can both show
    /// without a shortcut, splitting the shelf between them
    /// (`ShelfArrangement`).
    public var bothBarsCanShow: Bool {
        spaceBarStyle.visibility.showsUnprompted && anyAppBarCanShow
    }

    /// True while any bar shows without its shortcut.
    public var shelfShows: Bool {
        spaceBarStyle.visibility.showsUnprompted || anyAppBarCanShow
    }

    /// What the Space Bar draws from: the shelf and its own style.
    public var spaceBarLook: SpaceBarLook {
        SpaceBarLook(
            shelf: kiwishelf,
            bar: spaceBarStyle,
            sheen: borderStyle.sheen
        )
    }

    /// The shelf and the App Bar's global style, before any
    /// layout's overrides — what `AppBarHosting.resolvedBar`
    /// resolves from.
    public var appBarGlobalLook: AppBarLook {
        AppBarLook(
            shelf: kiwishelf,
            bar: appBarStyle,
            sheen: borderStyle.sheen
        )
    }

    /// What a layout's App Bar draws from: the shelf and the App
    /// Bar's style after that layout's overrides — the one body,
    /// which `AppBarHosting.resolvedBar` calls too.
    public func appBarLook(for bar: LayoutAppBar) -> AppBarLook {
        bar.look(on: appBarGlobalLook)
    }

    /// Where a mode's App Bar is stored — the ONE place that
    /// decides which layouts host an App Bar (#527): reading
    /// (`appBarHost(for:)`) and writing (`setAppBarVisibility`)
    /// both derive from here, so a third hosting layout is one
    /// edit. `KiwiCore`'s per-space twin keeps its own switch by
    /// necessity — two mirrors, which §2.4 allows, never three.
    public static func appBarPath(
        for mode: LayoutMode
    ) -> WritableKeyPath<TilingSettings, LayoutAppBar>? {
        switch mode {
        case .monocle: return \.monocle.appBar
        case .scrolling: return \.scrolling.appBar
        default: return nil
        }
    }

    /// The bar-hosting layout for a mode, or nil for one that
    /// carries no App Bar (`appBarPath(for:)`).
    public func appBarHost(
        for mode: LayoutMode
    ) -> AppBarHosting? {
        Self.appBarPath(for: mode).map { self[keyPath: $0] }
    }

    /// Every bar-hosting layout's bar configuration.
    public var appBarHosts: [LayoutAppBar] {
        LayoutMode.allCases.compactMap {
            appBarHost(for: $0)?.appBar
        }
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
            minimum: minWindowSize(for: .scrolling, in: space)
                .along(horizontal: horizontal)
        )
    }

    /// Builds a LayoutContext. `sticky` (#414 v2) is REQUIRED so every call
    /// site chooses (the `forceRetile` pattern, §5): a
    /// frame-producing build that silently omitted it would
    /// diverge only when a sticky is piled — the hardest drift to
    /// spot; strip-geometry builds pass `[]` explicitly.
    /// `stackFlip` (#2771) is required for the same reason: the
    /// side a stack Space draws on the Desktop shown now.
    /// `focusedOverride` (#431), `screenNeighbors` (#878, #881),
    /// `sizeBounds` (#677) and `parkBounds` (#2235) follow the
    /// same choose-or-omit shape.
    public func context(
        bounds: CGRect,
        space: Space,
        sticky: Set<WindowID>,
        stackFlip: StackParams.StackPosition?,
        focusedOverride: WindowID? = nil,
        screenNeighbors: ScreenNeighbors = ScreenNeighbors(),
        sizeBounds: [WindowID: EffectiveSizeBound] = [:],
        parkBounds: CGRect? = nil
    ) -> LayoutContext {
        var context = LayoutContext(
            bounds: bounds,
            gaps: gaps(for: space.id),
            focused: focusedOverride ?? space.focused,
            minWindowSize: minWindowSize(for: space.mode, in: space.id),
            stackWeights: space.stackWeights,
            scrollRest: space.scrollRest,
            trackBreaks: space.trackBreaks,
            runHeads: space.runHeads,
            runTails: space.runTails,
            trackWeights: space.trackWeights,
            sticky: sticky,
            screenNeighbors: screenNeighbors,
            sizeBounds: sizeBounds,
            bsp: resolvedBsp(for: space),
            stack: resolvedStack(for: space, flip: stackFlip),
            scrolling: resolvedScrolling(for: space),
            grid: resolvedGrid(for: space),
            monocle: resolvedMonocle(for: space.id),
            track: resolvedTrack(for: space.id)
        )
        context.parkBounds = parkBounds
        return context
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
