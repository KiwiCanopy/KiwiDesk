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
            strip: strip,
            style: style
        )
    }

    /// The display's Spaces in profile order, each with its
    /// identifier and app glyphs. `hide_empty` drops empty
    /// spaces except the current one (it always stays — cold
    /// start must not collapse the strip).
    private func spaceBarItems(
        display: DisplayID,
        style: SpaceBarStyle
    ) -> [SpaceBarOverlay.Item] {
        let current = state.workspaces.currentSpace(on: display)
        return state.workspaces.spaces(on: display)
            .compactMap { id in
                guard let space = state.workspaces[id] else {
                    return nil
                }
                let apps = spaceBarApps(
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
                    active: id == current
                )
            }
    }

    /// One glyph per window in the space's flat array order
    /// (grouping and the overflow cap land in stage 2).
    private func spaceBarApps(
        in space: Space,
        style: SpaceBarStyle
    ) -> [SpaceBarItemView.App] {
        space.windows.compactMap { id in
            guard let window = state.windows[id] else {
                return nil
            }
            let name = window.appName
            let icon = NSRunningApplication(
                processIdentifier: window.pid
            )?.icon
            var glyph = appFont.glyph(
                forAppName: name,
                source: style.iconSource
            )
            if glyph == nil, icon == nil {
                // No image either way: fall back to the App
                // Font (specific glyph, else `Default`) so the
                // slot never renders blank — monochrome, so it
                // adapts to the bar's colors.
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
                focused: space.focused == id
            )
        }
    }

    /// The configured Space icon (SF Symbol | emoji | single
    /// character), or the settled fallbacks: numeric id →
    /// `N.square`, named space → 2-character uppercase
    /// monogram.
    private func spaceIdentifier(
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
            let emoji = icon.unicodeScalars.contains {
                $0.properties.isEmojiPresentation
            }
            return .text(icon, tinted: !emoji)
        }
        if Int(id.raw) != nil {
            return .symbol("\(id.raw).square")
        }
        return .text(
            String(id.raw.prefix(2)).uppercased(),
            tinted: true
        )
    }
}
