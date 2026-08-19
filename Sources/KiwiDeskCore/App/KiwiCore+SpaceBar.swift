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
        return SpaceBarManager.Bar(
            display: display.id,
            items: items,
            frontApp: frontApp(display: display.id, style: style),
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
    func frontApp(
        display: DisplayID,
        style: SpaceBarStyle
    ) -> SpaceBarItemView.App? {
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
        // Deliberately NOT edge-aware: a vertical bar is handed
        // a title it never draws (`layoutFrontName` returns
        // early, and `frontExtent` measures nothing), because
        // the style here is global while the edge is the one
        // thing a per-display bar could differ on. The cost is
        // that a vertical bar's AX label takes the two-argument
        // frame for text it does not show; the alternative —
        // resolving the edge in the driver — would put a
        // rendering question in the wrong layer.
        let title = state.windows[focused]?.title ?? ""
        app.title =
            title.isEmpty
            ? nil
            : AppBarStyle.cappedTitle(
                title,
                to: style.resolvedTitleCap
            )
        return app
    }

    /// The display's Spaces in profile order, each with its
    /// identifier and app glyphs. `hide_empty` drops empty
    /// spaces except the current one (it always stays — cold
    /// start must not collapse the strip).
    func spaceBarItems(
        display: DisplayID,
        style: SpaceBarStyle
    ) -> [SpaceBarOverlay.Item] {
        let current = state.workspaces.currentSpace(on: display)
        return state.workspaces.spaces(on: display)
            .compactMap { id in
                guard let space = state.workspaces[id] else {
                    return nil
                }
                let (apps, overflow, focusHidden) = spaceBarApps(
                    in: space,
                    style: style,
                    isCurrent: id == current
                )
                if style.hideEmpty, apps.isEmpty,
                    id != current
                {
                    return nil
                }
                return SpaceBarOverlay.Item(
                    space: id,
                    spaceGlyph: spaceIdentifier(for: id),
                    apps: apps,
                    active: id == current,
                    overflow: overflow,
                    // Only the active space carries the system focus;
                    // an inactive space's `focused` is just its own
                    // last-focused window, not the tint's subject.
                    focusInOverflow: id == current && focusHidden
                )
            }
    }

    /// Adjacent same-app runs in the space's flat array order
    /// collapse into one glyph + count (the App Bar's grouping
    /// model, without focused-inside expansion), then the cap
    /// keeps the first `style.resolvedGlyphCap` slots (#376).
    /// Grouping runs first by design so the cap counts app
    /// *groups*, not raw windows. Returns the visible slots and
    /// the number of *windows* hidden past the cap (the "+n"
    /// badge).
    func spaceBarApps(
        in space: Space,
        style: SpaceBarStyle,
        isCurrent: Bool = true
    ) -> (
        apps: [SpaceBarItemView.App],
        overflow: Int,
        focusHidden: Bool
    ) {
        // One pass: ids and names stay index-aligned with no
        // unreachable "?" fallback. Sticky glyphs TRAVEL with
        // the user (#414 QA): a sticky window is listed only
        // under the CURRENT space's item — appended there when
        // homed elsewhere, pruned from every inactive item
        // (including its home's) — so one glyph always sits
        // where the user is, instead of cloning onto every
        // item at once.
        let activeID = isCurrent ? space.id : activeSpace?.id
        let members = state.effectiveMembers(
            of: space,
            activeSpace: activeID
        )
        // Transient overlays (a popup's AX windows, a launcher
        // panel) are dropped HERE, before grouping and the cap,
        // so no slot is reserved for a glyph nobody draws — the
        // same draw-time decision the focus ring already makes
        // (#300, #683), never a widening of tracking or of the
        // ignore gate.
        let pairs = members.compactMap { id -> (WindowID, String, Bool)? in
            guard let window = state.windows[id],
                !window.isTransientOverlay
            else { return nil }
            let isSpecial = window.isFloating || window.isSticky
            return (id, window.appName, isSpecial)
        }
        let windows = pairs.map { $0.0 }
        let groups = Self.adjacentRuns(
            of: pairs.map { $0.1 },
            specials: pairs.map { $0.2 }
        ).map { Array(windows[$0]) }
        let cap = style.resolvedGlyphCap
        let visible = groups.prefix(cap)
        let hidden = groups.dropFirst(cap)
        let apps = visible.compactMap { group in
            spaceBarApp(group: group, space: space, style: style)
        }
        // The focused window can be hidden past the cap: the "+n"
        // then tints to signal focus is behind it (#376).
        let focusHidden =
            space.focused.map { focus in
                hidden.contains { $0.contains(focus) }
            } ?? false
        return (apps, hidden.reduce(0) { $0 + $1.count }, focusHidden)
    }

    /// One glyph slot for a same-app run.
    private func spaceBarApp(
        group: [WindowID],
        space: Space,
        style: SpaceBarStyle
    ) -> SpaceBarItemView.App? {
        guard let first = group.first,
            let window = state.windows[first]
        else { return nil }
        let name = window.appName
        let icon = NSRunningApplication(
            processIdentifier: window.pid
        )?.icon
        var glyph = appFont.glyph(
            forAppName: name,
            source: style.iconSource
        )
        if glyph == nil, icon == nil {
            // No image either way: fall back to the App Font
            // (specific glyph, else `Default`) so the slot
            // never renders blank — monochrome, so it adapts
            // to the bar's colors.
            glyph =
                appFont.glyph(
                    forAppName: name,
                    source: .appFont
                )
                ?? appFont.glyph(
                    forAppName: "Default",
                    source: .appFont
                )
        }
        return SpaceBarItemView.App(
            name: name,
            icon: icon,
            glyph: glyph,
            // The SYSTEM focus, not this space's own memory:
            // a foreign sticky window can hold it (#414 QA —
            // its glyph was stuck on the unfocused dim tier).
            focused: state.workspaces.lastFocused
                .map(group.contains) ?? false,
            count: group.count,
            // Badge inheritance (#414): a group aggregates its
            // children's states — an "at least one" signal.
            sticky: group.contains {
                state.windows[$0]?.isSticky == true
            },
            floating: group.contains {
                state.windows[$0]?.isFloating == true
            },
            // The run's first sticky member picks the badge glyph
            // (#445): global → infinity, display → pin.fill.
            stickyScope: group.compactMap {
                state.windows[$0]
            }.first(where: \.isSticky)?.stickyScope ?? .none
        )
    }

    /// The configured Space icon (SF Symbol | emoji | single
    /// character), or the settled fallbacks: numeric id →
    /// plain tinted digits, named space → 2-character
    /// uppercase monogram.
    func spaceIdentifier(
        for id: SpaceID
    ) -> SpaceBarItemView.Identifier {
        if let icon = tiler.settings.spaceIcons[id],
            !icon.isEmpty
        {
            if NSImage(
                systemSymbolName: icon,
                accessibilityDescription: nil
            ) != nil {
                return .symbol(icon)
            }
            // Emoji render untinted (they take no template
            // tint); plain characters follow the state color.
            // U+FE0F covers text-default scalars forced into
            // emoji presentation ("❤️", "☀️").
            let emoji = icon.unicodeScalars.contains {
                $0.properties.isEmojiPresentation
                    || $0.value == 0xFE0F
            }
            return .text(icon, tinted: !emoji)
        }
        // Numeric ids render as plain digits (QA 2026-07-19):
        // the old `N.square` symbol is self-bordered, and with
        // the default boxed background wrapping the item it
        // read as a box-in-a-box. Plain text also drops the
        // symbol's 0–50 range limit. Digits skip the monogram's
        // uppercase-prefix (they are already their own short
        // string).
        if Int(id.raw) != nil {
            // Three digits still fit the square cell; longer
            // ids truncate like the monogram rather than clip
            // under the item's masksToBounds.
            return .text(
                String(id.raw.prefix(3)),
                tinted: true
            )
        }
        return .text(
            String(id.raw.prefix(2)).uppercased(),
            tinted: true
        )
    }
}
