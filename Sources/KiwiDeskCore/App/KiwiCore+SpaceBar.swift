import AppKit

/// Keeps the Space Bars in sync with workspace state (#293).
/// Driven from `retile()` — which already fires on every
/// structural, focus, mode, settings, space, and profile
/// change — so the bar needs no event machinery of its own.
/// One bar per display, listing that display's Spaces in
/// profile order. Everything is read from snapshotted state:
/// no AX calls in bar building.
extension KiwiCore {
    func updateSpaceBar() {
        let style = tiler.settings.spaceBarStyle
        guard style.enabled else {
            spaceBars.sync([])
            return
        }
        // No main-screen cold-start fallback (unlike the App
        // Bar): the display list seeds on the first event loop
        // tick and the bar appears with it.
        let bars = state.workspaces.allDisplays.compactMap {
            spaceBar(for: $0, style: style)
        }
        spaceBars.sync(bars)
    }

    /// One display's bar, or nil when it has no screen or no
    /// visible items.
    private func spaceBar(
        for display: Display,
        style: SpaceBarStyle
    ) -> SpaceBarManager.Bar? {
        // Same fullscreen-space stand-down as the App Bar
        // (#670): the panel joins every space by construction,
        // so the per-display verdict gates the build and nil
        // retires the overlay through the manager.
        guard
            NativeSpaces.currentSpaceIsUser(display: display.id),
            let screen = screen(for: display.id)
        else { return nil }
        let items = spaceBarItems(
            display: display.id,
            style: style
        )
        guard !items.isEmpty,
            let strip = SpaceBarGeometry.strip(
                in: GeometryUtils.axVisibleFrame(of: screen),
                style: style
            )
        else { return nil }
        let front = frontApp(display: display.id, style: style)
        return SpaceBarManager.Bar(
            display: display.id,
            items: items,
            frontApp: front?.app,
            frontWindow: front?.window,
            strip: strip,
            style: style,
            stateMarkColors: StateMarkColors(
                sticky: tiler.settings.stickyStyle.color,
                floating: tiler.settings.floatingStyle.color
            )
        )
    }

    /// The front-app segment's content (#293 verdict 6): the
    /// focused window of the space this display currently
    /// shows. Nil while the toggle is off or nothing is
    /// focused — the segment then hides.
    ///
    /// Deliberately NOT filtered by `isTransientOverlay`, unlike
    /// the glyph strip below (#683): the segment answers "which
    /// app is in front", not "which windows does this Space
    /// hold". A popup that surfaces as an AX window belongs to
    /// the app the user is working in — the launcher class that
    /// would name a *different* app is never tracked at all
    /// (#448) — and the segment draws only that app's glyph and
    /// name, no state badge and no slot, so it says "Front app:
    /// Telegram" while a Telegram menu is open, which is true.
    /// Filtering here would instead hide the whole segment for
    /// as long as a menu is held open, re-laying the strip out
    /// on every right-click.
    ///
    /// What DOES stand down while an overlay holds focus is the
    /// focus TINT on the strip's glyphs — the overlay is not
    /// drawn, so no group contains `lastFocused`. That matches
    /// the focus ring, which #300 already suppresses for the
    /// same window; `SpaceBarOverlayFilterTests` pins both
    /// halves.
    ///
    /// Returns the window ALONGSIDE its render value: the
    /// painted bar records which window its segment is about, so
    /// the title-refresh gate can ask it instead of re-deriving
    /// this guard chain (`SpaceBarManager.showsTitle(of:)`).
    func frontApp(
        display: DisplayID,
        style: SpaceBarStyle
    ) -> (window: WindowID, app: SpaceBarItemView.App)? {
        guard style.showFrontApp,
            let current = state.workspaces.currentSpace(
                on: display
            ),
            let space = state.workspaces[current],
            let focused = space.focused
        else { return nil }
        guard
            var app = spaceBarApp(
                group: [focused],
                space: space,
                style: style
            )
        else { return nil }
        // The segment IS the focused window, so it names that
        // window rather than repeating its app: an app already
        // shown by the icon beside it, and by every glyph in the
        // run. Nil leaves `layoutFrontName` on the app-name
        // fallback, which is what an empty title (#160) wants.
        //
        // Deliberately NOT edge-aware. A vertical bar draws no
        // front name (`layoutFrontName` returns early, and
        // `frontExtent` measures nothing) but it still ANNOUNCES
        // one: the segment's accessibility label is built from
        // this title on every edge
        // (`SpaceBarOverlay+FrontApp`). Resolving the edge here
        // would silence VoiceOver on a vertical bar to save a
        // string nobody pays for. The refresh gate keeps the
        // announced title current instead, which is why
        // `SpaceBarManager.showsTitle(of:)` does not gate on the
        // edge either (review 2026-08-20).
        let title = state.windows[focused]?.title ?? ""
        app.title =
            title.isEmpty
            ? nil
            : AppBarStyle.cappedTitle(
                title,
                to: style.resolvedTitleCap
            )
        return (window: focused, app: app)
    }
}
