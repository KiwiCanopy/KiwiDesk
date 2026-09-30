import AppKit

/// The shelves per display (#1517, #1731): which bars show there,
/// on which edge, what each needs, and the segment
/// `ShelfArrangement` gives it — one shelf while the bars share an
/// edge, one per bar while they are split. The one refresh
/// (`updateBars`) builds them once per display for both bars, so
/// neither re-derives the other's presence and the two can never
/// overlap.
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
        defer {
            publishStatusSpaceMark()
            spaceBars.publishLiveOnly(liveOnlySpaces)
        }
        syncFontIssue()
        let settings = tiler.settings
        let displays = state.workspaces.allDisplays
        guard !displays.isEmpty else {
            let fallback = appBarFallback(settings: settings)
            shelves.holdingRelayout {
                appBars.sync(fallback)
                spaceBars.sync([])
            }
            // A lone bar's slot IS its strip.
            syncShelves(
                fallback.map {
                    ShelfStrip(
                        display: $0.display,
                        edge: $0.style.edge,
                        strip: $0.strip,
                        carriesSpace: false,
                        carriesApp: true
                    )
                },
                settings: settings
            )
            return
        }
        let look = settings.spaceBarLook
        var appBarsShown: [AppBarManager.Bar] = []
        var spaceBarsShown: [SpaceBarManager.Bar] = []
        var strips: [ShelfStrip] = []
        for display in displays {
            // A fullscreen space hosts the panels by construction
            // (`.canJoinAllSpaces` + `.fullScreenAuxiliary`), so
            // the stand-down (#670, and a presentation in front,
            // #1787) gates here, read once for both bars: nil
            // retires each overlay through its manager, keeping
            // `shownStrips` consistent with the float clamp.
            let down = shelfStandsDown(on: display.id)
            let app =
                down
                ? nil : appBarContent(on: display.id, settings: settings)
            let items =
                down
                ? nil : spaceBarContent(on: display.id, style: look)
            guard app != nil || items != nil,
                let screen = screen(for: display.id)
            else { continue }
            // Chrome is drawn on a REAL screen, so the shelf is
            // measured on its visible frame rather than the
            // engine's `layoutBounds(on:)` seam: one of the
            // deliberate `visibleBounds` exemptions
            // (`VisibleBoundsRoutingTests.allowed`, #537).
            let plans = shelfPlans(
                visible: GeometryUtils.axVisibleFrame(of: screen),
                settings: settings,
                spaceItems: items,
                app: app
            )
            strips += plans.map {
                ShelfStrip(
                    display: display.id,
                    edge: $0.edge,
                    strip: $0.strip,
                    carriesSpace: $0.arrangement.space != nil,
                    carriesApp: $0.arrangement.app != nil,
                    divider: $0.arrangement.divider
                )
            }
            if let app,
                let plan = plans.first(where: { $0.arrangement.app != nil }),
                let bar = placedBar(app, display: display.id, plan: plan)
            {
                appBarsShown.append(bar)
            }
            if let items,
                let plan = plans.first(where: {
                    $0.arrangement.space != nil
                }),
                let bar = placedSpaceBar(
                    items,
                    display: display.id,
                    plan: plan,
                    appBarShows: app != nil,
                    style: look
                )
            {
                spaceBarsShown.append(bar)
            }
        }
        shelves.holdingRelayout {
            appBars.sync(appBarsShown)
            spaceBars.sync(spaceBarsShown)
        }
        syncShelves(strips, settings: settings)
    }

    /// One shelf to show: its display, edge and strip, which bars
    /// its plan placed on it, and the divider its arrangement set.
    struct ShelfStrip {
        let display: DisplayID
        let edge: AppBarEdge
        let strip: CGRect
        let carriesSpace: Bool
        let carriesApp: Bool
        var divider: ShelfArrangement.Divider? = nil
    }

    /// Hands each shelf the sections its bars just rendered on its
    /// edge, at the slots the plan gave them.
    private func syncShelves(
        _ strips: [ShelfStrip],
        settings: TilingSettings
    ) {
        shelves.sync(
            strips.map { shelf in
                ShelfManager.Shelf(
                    display: shelf.display,
                    edge: shelf.edge,
                    strip: shelf.strip,
                    shelf: settings.kiwishelf,
                    sheen: settings.borderStyle.sheen,
                    space: shelf.carriesSpace
                        ? spaceBars.shownOverlay(on: shelf.display) : nil,
                    app: shelf.carriesApp
                        ? appBars.shownOverlay(on: shelf.display) : nil,
                    divider: shelf.divider
                )
            }
        )
    }

    /// What one display's App Bar would draw, before the shelf
    /// places it.
    struct AppBarContent {
        let space: Space
        let style: AppBarLook
        let groups: [[WindowID]]
        /// The groups' items, then each float's (#1826).
        let items: [AppBarOverlay.Item]
    }

    /// The App Bar content for the space shown on `display`, or
    /// nil when that space hosts no enabled, non-empty bar.
    func appBarContent(
        on display: DisplayID,
        settings: TilingSettings
    ) -> AppBarContent? {
        guard
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
        let floats = appBarFloats(in: space)
        guard !groups.isEmpty || !floats.isEmpty else { return nil }
        return AppBarContent(
            space: space,
            style: style,
            groups: groups,
            items: groups.map { barItem(for: $0, style: style) }
                + floats.map {
                    barItem(for: [$0], style: style, floating: true)
                }
        )
    }

    /// The Space Bar's items on `display` — the layer item
    /// leading — or nil when the bar is off or has nothing to
    /// show there.
    func spaceBarContent(
        on display: DisplayID,
        style: SpaceBarLook
    ) -> [SpaceBarOverlay.Item]? {
        guard style.enabled else { return nil }
        var items = spaceBarItems(display: display, style: style)
        guard !items.isEmpty else { return nil }
        // After the emptiness guard: a layer never draws a bar
        // on a screen with no Space item to lead.
        if let layer = spaceBarLayerItem() {
            items.insert(layer, at: 0)
        }
        return items
    }
}
