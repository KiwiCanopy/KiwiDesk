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
        guard let screen = screen(for: display.id) else {
            return nil
        }
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
            style: style
        )
    }

    /// The front-app segment's content (#293 verdict 6): the
    /// focused window of the space this display currently
    /// shows. Nil while the toggle is off or nothing is
    /// focused — the segment then hides.
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
        return spaceBarApp(
            group: [focused],
            space: space,
            style: style
        )
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
                    style: style
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
        style: SpaceBarStyle
    ) -> (
        apps: [SpaceBarItemView.App],
        overflow: Int,
        focusHidden: Bool
    ) {
        // One pass: ids and names stay index-aligned with no
        // unreachable "?" fallback.
        let pairs = space.windows.compactMap { id in
            state.windows[id].map { (id, $0.appName) }
        }
        let windows = pairs.map(\.0)
        let groups = Self.adjacentRuns(of: pairs.map(\.1))
            .map { Array(windows[$0]) }
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
            focused: space.focused.map(group.contains) ?? false,
            count: group.count,
            // Badge inheritance (#414): a group aggregates its
            // children's states — an "at least one" signal.
            sticky: group.contains {
                state.windows[$0]?.isSticky == true
            },
            floating: group.contains {
                state.windows[$0]?.isFloating == true
            }
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
