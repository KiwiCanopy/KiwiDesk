import AppKit

/// The KiwiShelf per display (#1517): which bars show there, what
/// each needs, and the segment `ShelfArrangement` gives it. The
/// one refresh (`updateBars`) builds it once per display for both
/// bars, so neither re-derives the other's presence and the two
/// can never overlap.
extension KiwiCore {
    /// The ONE bar refresh (#1517): each display's plan built
    /// once from both bars' content, then both managers synced
    /// from it, so a change to either bar's need moves the other
    /// in the same pass. Driven from `retile()` — which fires on
    /// every structural, focus, mode, settings, space and profile
    /// change — plus the few changes that retile nothing (a
    /// focus, a layer switch, a title, Reduce transparency). The
    /// menu bar's stand-in rides the same refresh (#1413).
    func updateBars() {
        defer { publishStatusSpaceMark() }
        let settings = tiler.settings
        let displays = state.workspaces.allDisplays
        guard !displays.isEmpty else {
            appBars.sync(appBarFallback(settings: settings))
            spaceBars.sync([])
            return
        }
        let look = settings.spaceBarLook
        var appBarsShown: [AppBarManager.Bar] = []
        var spaceBarsShown: [SpaceBarManager.Bar] = []
        for display in displays {
            let app = appBarContent(on: display.id, settings: settings)
            let items = spaceBarContent(on: display.id, style: look)
            guard app != nil || items != nil,
                let screen = screen(for: display.id)
            else { continue }
            // Chrome is drawn on a REAL screen, so the shelf is
            // measured on its visible frame rather than the
            // engine's `layoutBounds(on:)` seam: one of the
            // deliberate `visibleBounds` exemptions
            // (`VisibleBoundsRoutingTests.allowed`, #537).
            let plan = shelfPlan(
                visible: GeometryUtils.axVisibleFrame(of: screen),
                settings: settings,
                spaceItems: items,
                app: app
            )
            if let app,
                let bar = placedBar(app, display: display.id, plan: plan)
            {
                appBarsShown.append(bar)
            }
            if let items,
                let bar = placedSpaceBar(
                    items,
                    display: display.id,
                    plan: plan,
                    sharesWithAppBar: app != nil,
                    style: look
                )
            {
                spaceBarsShown.append(bar)
            }
        }
        appBars.sync(appBarsShown)
        spaceBars.sync(spaceBarsShown)
    }

    /// What one display's App Bar would draw, before the shelf
    /// places it.
    struct AppBarContent {
        let space: Space
        let style: AppBarLook
        let groups: [[WindowID]]
        let items: [AppBarOverlay.Item]
    }

    /// One display's shelf: its strip in AX coordinates and each
    /// shown bar's slot along it.
    struct ShelfPlan {
        let strip: CGRect
        let horizontal: Bool
        let arrangement: ShelfArrangement

        /// The strip's length along the edge.
        var length: CGFloat {
            horizontal ? strip.width : strip.height
        }

        func segment(_ slot: ShelfArrangement.Slot) -> CGRect {
            slot.rect(in: strip, horizontal: horizontal)
        }
    }

    /// The App Bar content for the space shown on `display`, or
    /// nil when that space hosts no enabled, non-empty bar.
    func appBarContent(
        on display: DisplayID,
        settings: TilingSettings
    ) -> AppBarContent? {
        guard
            // A fullscreen space hosts the panels by
            // construction (`.canJoinAllSpaces` +
            // `.fullScreenAuxiliary`), so the stand-down (#670)
            // gates here: nil retires the overlay through the
            // manager, keeping `shownStrips` consistent with
            // `clampFloatsClearOfBars`.
            NativeSpaces.currentSpaceIsUser(display: display),
            let id = state.workspaces.currentSpace(on: display),
            let space = state.workspaces[id]
        else { return nil }
        return appBarContent(space: space, settings: settings)
    }

    /// The App Bar content for `space`, or nil when its layout
    /// hosts no enabled bar or it has no items.
    func appBarContent(
        space: Space,
        settings: TilingSettings
    ) -> AppBarContent? {
        guard let host = barHost(for: space), host.appBar.enabled
        else { return nil }
        let style = host.resolvedBar(
            global: settings.appBarGlobalLook
        )
        let groups = barGroups(
            in: space,
            grouping: style.groupAdjacentWindows
        )
        guard !groups.isEmpty else { return nil }
        return AppBarContent(
            space: space,
            style: style,
            groups: groups,
            items: groups.map { barItem(for: $0, style: style) }
        )
    }

    /// The Space Bar's items on `display` — the layer item
    /// leading — or nil when the bar is off or has nothing to
    /// show there.
    func spaceBarContent(
        on display: DisplayID,
        style: SpaceBarLook
    ) -> [SpaceBarOverlay.Item]? {
        // Same fullscreen-space stand-down as the App Bar (#670).
        guard style.enabled,
            NativeSpaces.currentSpaceIsUser(display: display)
        else { return nil }
        var items = spaceBarItems(display: display, style: style)
        guard !items.isEmpty else { return nil }
        // After the emptiness guard: a layer never draws a bar
        // on a screen with no Space item to lead.
        if let layer = spaceBarLayerItem() {
            items.insert(layer, at: 0)
        }
        return items
    }

    /// Places the shown bars on the shelf of a screen whose
    /// visible frame is `visible` — the screen's, never the
    /// layout bounds, which the shelf has already left.
    func shelfPlan(
        visible: CGRect,
        settings: TilingSettings,
        spaceItems: [SpaceBarOverlay.Item]?,
        app: AppBarContent?
    ) -> ShelfPlan {
        let shelf = settings.kiwishelf
        let strip = ShelfGeometry.strip(in: visible, shelf: shelf)
        let horizontal = shelf.edge.isHorizontal
        let length = horizontal ? strip.width : strip.height
        let depth = horizontal ? strip.height : strip.width
        let spaceNeed = spaceItems.map {
            SpaceBarOverlay.naturalLength(
                items: $0,
                depth: depth,
                gap: shelf.itemGap
            )
        }
        let appNeed = app.map {
            AppBarOverlay.naturalLength(
                items: $0.items,
                style: $0.style,
                thickness: depth,
                capAxis: length
            )
        }
        return ShelfPlan(
            strip: strip,
            horizontal: horizontal,
            arrangement: ShelfArrangement.arrange(
                length: length,
                spaceNeed: spaceNeed,
                appNeed: appNeed,
                shelf: shelf
            )
        )
    }
}
