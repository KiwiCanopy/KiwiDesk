import AppKit

/// Keeps the indicator bars in sync with the spaces on screen.
/// Driven from `retile()`, which already fires on every
/// structural, focus, mode, and settings change. One bar per
/// display (#16): each display shows the bar of the space
/// currently visible on it, resolved through the total
/// space→display assignment (`resolveSpaceDisplays`). Any layout
/// that hosts a bar (monocle, scrolling) drives its display's
/// overlay; the bar's look is the global `AppBarStyle` overlaid
/// by that layout's own overrides.
extension KiwiCore {
    func updateAppBar() {
        let settings = tiler.settings
        let displays = state.workspaces.allDisplays
        // Cold start: `loadConfig()` can apply a profile and
        // retile before `eventLoop.start()` publishes the
        // displays, so `allDisplays` is briefly empty while a
        // bar-hosting space is already active. Fall back to the
        // active space on the main screen — the pre-#16
        // single-bar behavior — until the display list seeds.
        // Once seeded, an active space that resolves to no
        // display (so `resolveSpaceDisplays` never assigned it)
        // shows no bar; in the normal flow resolution always
        // assigns it first.
        guard !displays.isEmpty else {
            appBars.sync(mainScreenFallback(settings: settings))
            return
        }
        let bars = displays.compactMap {
            bar(for: $0, settings: settings)
        }
        appBars.sync(bars)
    }

    /// The bar for the space currently shown on `display`, or nil
    /// when that space hosts no enabled, non-empty bar.
    private func bar(
        for display: Display,
        settings: TilingSettings
    ) -> AppBarManager.Bar? {
        guard
            let id = state.workspaces.currentSpace(on: display.id),
            let space = state.workspaces[id],
            let host = barHost(for: space),
            host.appBar.enabled,
            let screen = screen(for: display.id)
        else { return nil }
        return buildBar(
            space: space,
            display: display.id,
            bounds: GeometryUtils.axVisibleFrame(of: screen),
            host: host,
            settings: settings
        )
    }

    /// Single bar for the active space on the main screen, used
    /// only until the display list is populated.
    private func mainScreenFallback(
        settings: TilingSettings
    ) -> [AppBarManager.Bar] {
        guard let space = activeSpace,
            let host = barHost(for: space),
            host.appBar.enabled,
            let screen = NSScreen.main ?? NSScreen.screens.first,
            let bar = buildBar(
                space: space,
                display: screen.kiwiDisplay?.id
                    ?? DisplayID(CGMainDisplayID()),
                bounds: GeometryUtils.axVisibleFrame(of: screen),
                host: host,
                settings: settings
            )
        else { return [] }
        return [bar]
    }

    /// Assembles one display's bar from its space and usable
    /// bounds; nil when the space has no items or the bar is off.
    private func buildBar(
        space: Space,
        display: DisplayID,
        bounds: CGRect,
        host: AppBarHosting,
        settings: TilingSettings
    ) -> AppBarManager.Bar? {
        let style = host.resolvedBar(
            global: settings.appBarStyle
        )
        // Space-first reservation (#293): the App Bar carves
        // inside the frame the Space Bar already inset — same
        // rule the retile path applies, reached through
        // `layoutBounds(from:)` rather than the engine's
        // `layoutBounds(on:)` seam because chrome is drawn on a
        // REAL screen: this is one of the deliberate
        // `visibleBounds` exemptions, and the reason lives in
        // `VisibleBoundsRoutingTests.allowed` (#537 review).
        // Empty sticky set: this context only carves the bar
        // strip (`usable` + `barFrame`), it never produces
        // per-window frames, so pile exemption cannot apply.
        let context = settings.context(
            bounds: settings.layoutBounds(from: bounds),
            space: space,
            sticky: []
        )
        let groups = barGroups(
            in: space,
            grouping: style.groupAdjacentWindows
        )
        guard !groups.isEmpty,
            let strip = host.barFrame(
                in: context.usable,
                global: settings.appBarStyle
            )
        else { return nil }
        return AppBarManager.Bar(
            display: display,
            space: space.id,
            items: groups.map { barItem(for: $0, style: style) },
            activeIndex: groups.firstIndex { group in
                appBarFocused(of: space).map(group.contains)
                    ?? false
            },
            strip: strip,
            style: style
        )
    }

    /// The `NSScreen` backing a tracked display, matched by its
    /// `CGDirectDisplayID`. Nil when the display is not currently
    /// connected to a screen.
    func screen(for display: DisplayID) -> NSScreen? {
        NSScreen.screens.first { $0.kiwiDisplay?.id == display }
    }

    /// The bar-hosting layout for a space, resolved through the
    /// per-space override path (#17) like every other layout
    /// consumer — today no per-space field is bar-visible (the
    /// overrides carry no `app_bar` tier and, since #293, the
    /// orientation no longer decides the edge), but a future
    /// per-space bar override lands here for free. The reorder
    /// path uses `barHost(for mode:)`, which needs no per-space
    /// geometry.
    func barHost(for space: Space) -> AppBarHosting? {
        switch space.mode {
        case .monocle:
            return tiler.settings.resolvedMonocle(for: space.id)
        case .scrolling:
            return tiler.settings.resolvedScrolling(for: space.id)
        default: return nil
        }
    }

    /// The bar-hosting layout for a space mode, or nil for modes
    /// that don't show a bar. Delegates to the one list on
    /// `TilingSettings` (#527) — do not re-enumerate the modes
    /// here.
    func barHost(for mode: LayoutMode) -> AppBarHosting? {
        tiler.settings.appBarHost(for: mode)
    }

    /// Drag-and-drop reorder from the bar: moves the item at
    /// slot `from` (a single window or a whole group) to slot
    /// `to` within `space`, rewriting the tiled order in place —
    /// floating windows keep their positions in the flat array.
    func moveBarItem(space id: SpaceID, from: Int, to: Int) {
        guard let space = state.workspaces[id],
            let host = barHost(for: space.mode)
        else { return }
        let style = host.resolvedBar(
            global: tiler.settings.appBarStyle
        )
        var groups = barGroups(
            in: space,
            grouping: style.groupAdjacentWindows
        )
        guard from != to,
            groups.indices.contains(from),
            groups.indices.contains(to)
        else { return }
        let moved = groups.remove(at: from)
        groups.insert(moved, at: min(to, groups.count))
        // Resolved before withSpace: reading `state` inside
        // its inout closure would violate exclusivity.
        // LOCAL-only (#414 v2): the writeback below maps only
        // this space's own array, while `groups` (built on the
        // injecting `effectiveTiledMembers`) can hold traveling
        // sticky items with no local slot. Both the slot set and
        // the reorder stream drop travelers — a foreign id in
        // `reordered.next()` would overwrite a local slot and
        // drop a real window. Dragging a traveler item therefore
        // reorders nothing: non-home reorder is a v2 non-goal.
        let tiled = Set(state.localTiledMembers(of: space))
        let stream = Array(groups.joined())
            .filter { tiled.contains($0) }
        // Stream and slots both derive from localTiledMembers,
        // so the counts provably match; a future drift between
        // the group source and the writeback should fail loud
        // here, not silently mis-map slots via the `?? id`
        // fallback below.
        assert(
            stream.count
                == space.windows.filter(tiled.contains).count
        )
        var reordered = stream.makeIterator()
        state.workspaces.withSpace(space.id) { sp in
            sp.windows = sp.windows.map { id in
                tiled.contains(id)
                    ? (reordered.next() ?? id) : id
            }
        }
        retile()
        // The drop is the same array mutation as `scrollingStep`'s
        // swap — which arms this — so it can land a window in an
        // overflowing edge pile whose stacking still reads for the
        // pre-drop order (#674). Armed after the retile (#153).
        //
        // ONLY for the active space. The restore path is
        // active-space-only throughout (`layoutInput`,
        // `runPendingZOrderRestore`), while a bar belongs to
        // whichever space is showing on ITS display — so a drop on
        // a second display's bar would restack the space the user
        // is not in and still leave the dropped row stale. The
        // secondary-display half of #674 is a separate decision,
        // not something to fake from here.
        if id == state.workspaces.activeSpace {
            scheduleScrollingZOrderRestoreIfOverflowing()
        }
    }
}
