import AppKit

/// The App Bar half of the bar refresh (`updateBars`,
/// `KiwiCore+Shelf`). One bar per display (#16): each display
/// shows the bar of the space currently visible on it, resolved
/// through the total space→display assignment
/// (`resolveSpaceDisplays`). Any layout that hosts a bar
/// (monocle, scrolling) drives its display's overlay; the bar's
/// look is the global `AppBarStyle` overlaid by that layout's own
/// overrides, and its place is the segment of the KiwiShelf it is
/// given (#1517).
extension KiwiCore {
    /// Single bar for the active space on the main screen, used
    /// only until the display list is populated — no Space Bar
    /// shows before it, so the App Bar has the shelf alone.
    /// Cold start: `loadConfig()` can apply a profile and retile
    /// before `eventLoop.start()` publishes the displays; once
    /// seeded, an active space that resolves to no display shows
    /// no bar.
    func appBarFallback(
        settings: TilingSettings
    ) -> [AppBarManager.Bar] {
        guard NativeSpaces.activeSpaceIsUser(),
            let space = activeSpace,
            let app = appBarContent(space: space, settings: settings),
            let screen = NSScreen.main ?? NSScreen.screens.first,
            let bar = placedBar(
                app,
                display: screen.kiwiDisplay?.id
                    ?? DisplayID(CGMainDisplayID()),
                plan: shelfPlan(
                    visible: GeometryUtils.axVisibleFrame(of: screen),
                    settings: settings,
                    spaceItems: nil,
                    app: app
                )
            )
        else { return [] }
        return [bar]
    }

    /// Assembles one display's bar in its shelf segment.
    func placedBar(
        _ app: AppBarContent,
        display: DisplayID,
        plan: ShelfPlan
    ) -> AppBarManager.Bar? {
        guard let slot = plan.arrangement.app else { return nil }
        var style = app.style
        style.alignment = slot.alignment
        return AppBarManager.Bar(
            display: display,
            space: app.space.id,
            items: app.items,
            activeIndex: app.groups.firstIndex { group in
                appBarFocused(of: app.space).map(group.contains)
                    ?? false
            },
            strip: plan.segment(slot),
            style: style,
            capAxis: plan.length
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
            global: tiler.settings.appBarGlobalLook
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
        state.workspaces.withSpace(space.id) {
            $0.reorder(tiled: stream, among: tiled)
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
