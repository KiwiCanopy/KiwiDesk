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
                let (apps, overflow) = spaceBarApps(
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
                    overflow: overflow
                )
            }
    }

    /// Visible glyph slots per space item (#293 stage 2):
    /// grouping runs first, then the cap.
    static let spaceBarGlyphCap = 5

    /// Adjacent same-app runs in the space's flat array order
    /// collapse into one glyph + count (the App Bar's grouping
    /// model, without focused-inside expansion), then the cap
    /// keeps the first `spaceBarGlyphCap` slots. Returns the
    /// visible slots and the number of *windows* hidden past
    /// the cap (the "+n" badge).
    func spaceBarApps(
        in space: Space,
        style: SpaceBarStyle
    ) -> (apps: [SpaceBarItemView.App], overflow: Int) {
        // One pass: ids and names stay index-aligned with no
        // unreachable "?" fallback.
        let pairs = space.windows.compactMap { id in
            state.windows[id].map { (id, $0.appName) }
        }
        let windows = pairs.map(\.0)
        let groups = Self.adjacentRuns(of: pairs.map(\.1))
            .map { Array(windows[$0]) }
        let visible = groups.prefix(Self.spaceBarGlyphCap)
        let hidden = groups.dropFirst(Self.spaceBarGlyphCap)
        let apps = visible.compactMap { group in
            spaceBarApp(group: group, space: space, style: style)
        }
        return (apps, hidden.reduce(0) { $0 + $1.count })
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
            count: group.count
        )
    }

    /// The configured Space icon (SF Symbol | emoji | single
    /// character), or the settled fallbacks: numeric id →
    /// `N.square`, named space → 2-character uppercase
    /// monogram.
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
        // `N.square` exists only for a bounded range (0–50);
        // probe before trusting it, else fall through to the
        // monogram like any named space.
        if Int(id.raw) != nil,
            NSImage(
                systemSymbolName: "\(id.raw).square",
                accessibilityDescription: nil
            ) != nil
        {
            return .symbol("\(id.raw).square")
        }
        return .text(
            String(id.raw.prefix(2)).uppercased(),
            tinted: true
        )
    }
}
