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
        let style = host.resolvedBar(global: settings.appBarStyle)
        let context = settings.context(
            bounds: bounds,
            space: space
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
            items: groups.map(barItem),
            activeIndex: groups.firstIndex { group in
                space.focused.map(group.contains) ?? false
            },
            strip: strip,
            style: style
        )
    }

    /// The `NSScreen` backing a tracked display, matched by its
    /// `CGDirectDisplayID`. Nil when the display is not currently
    /// connected to a screen.
    private func screen(for display: DisplayID) -> NSScreen? {
        NSScreen.screens.first { $0.kiwiDisplay?.id == display }
    }

    /// The bar-hosting layout for a space, resolving per-space
    /// layout overrides (#17) so the bar edge follows that
    /// space's own orientation. Used when building a display's
    /// bar; `barHost(for mode:)` stays for the reorder path,
    /// which needs no per-space geometry.
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
    /// that don't show a bar.
    func barHost(for mode: LayoutMode) -> AppBarHosting? {
        switch mode {
        case .monocle: return tiler.settings.monocle
        case .scrolling: return tiler.settings.scrolling
        default: return nil
        }
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
        var reordered = Array(groups.joined()).makeIterator()
        // Resolved before withSpace: reading `state` inside
        // its inout closure would violate exclusivity.
        let tiled = Set(
            space.windows.filter {
                state.windows[$0]?.isFloating == false
            }
        )
        state.workspaces.withSpace(space.id) { sp in
            sp.windows = sp.windows.map { id in
                tiled.contains(id)
                    ? (reordered.next() ?? id) : id
            }
        }
        retile()
    }
}
