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
    func updateBars(holdingForSwitch: Bool = true) {
        // A Desktop switch's batch is still reading its arrivals;
        // its fold refreshes the bars once they are tracked (#2347).
        // A stand-down that cannot wait passes `false`.
        guard !holdingForSwitch || !eventLoop.switchReads.isPending
        else {
            eventLoop.switchReads.barsOwed = true
            return
        }
        eventLoop.switchReads.barsOwed = false
        let measured = tiler.meter.begin(.bars)  // #1508
        defer {
            measured()
            publishStatusSpaceMark()
            spaceBars.publishLiveOnly(liveOnlySpaces)
        }
        syncDerivedIssues()
        let settings = tiler.settings
        BarMotion.shelfGlide = settings.animations.expandSeconds(at: appWide)
        BarMotion.revealLength = settings.animations.revealSeconds(
            at: appWide
        )
        BarMotion.peekMotion = settings.animations.onPeek
        let displays = state.workspaces.allDisplays
        guard !displays.isEmpty else {
            let fallback = appBarFallback(settings: settings)
            shelves.holdingRelayout {
                appBars.sync(fallback)
                spaceBars.sync([])
            }
            syncHidingShelves(HidingShelves())
            // A lone bar's slot IS its strip.
            syncShelves(
                fallback.map {
                    ShelfStrip(
                        placement: $0.placement,
                        edge: $0.style.edge,
                        strip: $0.strip,
                        carriesSpace: false,
                        carriesApp: true
                    )
                },
                settings: settings
            )
            retireDepartedBars(live: Set(fallback.map(\.placement)))
            overflowMarks.standingDown = []
            updateOverflowMarks()
            pocketPlate.standingDown = []
            updatePocketPlate(slots: [:])
            return
        }
        var appBarsShown: [AppBarManager.Bar] = []
        var spaceBarsShown: [SpaceBarManager.Bar] = []
        var strips: [ShelfStrip] = []
        var standingDown: Set<DisplayID> = []
        // The overflow marks sit on windows a maximize covers, so
        // they stand down there too (#2448, #3346).
        var marksStandingDown: Set<DisplayID> = []
        var hiding = HidingShelves()
        // The pocket's slot on each screen's bar edge (#2678).
        var pocketSlots: [DisplayID: CGRect] = [:]
        // Under Hidden it stands inside its edge's strip (#2793).
        var pocketStrips: [DisplayID: CGRect] = [:]
        // The neighbours an area's hiding edge is judged against,
        // read once for the pass (#3349, #3517).
        let neighbours = shelfNeighbourFrames()
        for display in displays {
            // A fullscreen space hosts the panels by construction
            // (`.canJoinAllSpaces` + `.fullScreenAuxiliary`), so
            // the stand-down (#670, and a presentation in front,
            // #1787) gates here, read once per screen for every
            // area's bars: nil retires each overlay through its
            // manager, keeping `shownStrips` consistent with the
            // float clamp. A maximize is no stand-down: it reads the
            // bars Hidden through `shown` (#3346).
            let down = shelfStandsDown(on: display.id)
            if down { standingDown.insert(display.id) }
            if down || screenMaximizes(on: display.id) {
                marksStandingDown.insert(display.id)
            }
            guard let screen = screen(for: display.id) else { continue }
            // Chrome is drawn on a REAL screen, so the shelf is
            // measured on its visible frame rather than the
            // engine's `layoutBounds(on:)` seam: one of the
            // deliberate `visibleBounds` exemptions
            // (`VisibleBoundsRoutingTests.allowed`, #537).
            let visible = GeometryUtils.axVisibleFrame(of: screen)
            // The Pocket rests in the screen's lead area alone.
            let lead = state.workspaces.leadPlacement(of: display.id)
            // One shelf per area, each for the Space it shows
            // (#3517 ruling 30); an unsplit screen is one area.
            // A screen with no placement record yet is one whole
            // area 0, as `placementOrWhole(of:)` names it.
            let records = state.workspaces.placements(of: display.id)
            let areas =
                records.isEmpty
                ? [
                    Placement(
                        id: state.workspaces.placementOrWhole(of: display.id),
                        area: ScreenSplit.wholeArea(
                            width: Int(display.frame.width),
                            height: Int(display.frame.height)
                        ),
                        key: ScreenAreaKey(
                            fingerprint: display.fingerprint,
                            areaID: 0
                        )
                    )
                ] : records
            for placement in areas {
                let id = placement.id
                // Each bar's edge and visibility as THIS area has
                // them (#1948), so the plan and every style a bar
                // draws carry them, and a tiling-off Space's Hidden
                // bars (#3151).
                let shown = shelfSettings(on: id)
                let look = shown.spaceBarLook
                let app = down ? nil : appBarContent(on: id, settings: shown)
                let items = down ? nil : spaceBarContent(on: id, style: look)
                guard app != nil || items != nil else { continue }
                let carriesPocket = id == lead
                let reveal = shelves.reveal
                let hover = maximizedHoverBars(on: id)
                let planned = shelfPlans(
                    visible: shelfFrame(
                        of: placement,
                        visible: visible,
                        on: screen
                    ),
                    settings: shown,
                    mode: shownMode(of: state.workspaces.activeSpace(on: id)),
                    spaceItems: items,
                    app: app,
                    pocket: carriesPocket && pocketRests(on: display.id),
                    hover: hover,
                    drawn: { reveal.drawn($0, placement: id) }
                )
                hiding.file(
                    planned,
                    placement: id,
                    frame: cocoaFrame(of: placement, on: screen),
                    items: items,
                    screens: neighbours,
                    reveal: reveal,
                    hover: hover,
                    settings: shown
                )
                let plans = planned.filter(\.drawsAny)
                if carriesPocket {
                    if let plan = plans.first(where: {
                        $0.arrangement.pocket != nil
                    }),
                        let slot = plan.arrangement.pocket
                    {
                        pocketSlots[display.id] = plan.segment(slot)
                    }
                    pocketStrips[display.id] = Self.pocketStrip(
                        in: planned,
                        edge: shown.kiwishelf.pocketEdge,
                        hiding: { hiding.marks[$0] != nil },
                        placement: id
                    )
                }
                strips += plans.map {
                    ShelfStrip(
                        placement: id,
                        edge: $0.edge,
                        strip: $0.strip,
                        carriesSpace: $0.arrangement.space != nil,
                        carriesApp: $0.arrangement.app != nil,
                        divider: $0.arrangement.divider,
                        slides: $0.slides,
                        mark: hiding.marks[
                            ShelfManager.Key(placement: id, edge: $0.edge)
                        ],
                        pocketSlot: $0.arrangement.pocket.map($0.segment)
                    )
                }
                if let app,
                    let plan = plans.first(where: {
                        $0.arrangement.app != nil
                    }),
                    let bar = placedBar(app, placement: id, plan: plan)
                {
                    appBarsShown.append(bar)
                }
                if let items,
                    let plan = plans.first(where: {
                        $0.arrangement.space != nil
                    }),
                    let bar = placedSpaceBar(
                        items,
                        placement: id,
                        plan: plan,
                        // An App Bar in this area drawn or resting as
                        // a handle, on any edge, stands the front app
                        // down; only a Hidden one leaves it room
                        // (#3359).
                        appBarShows: planned.contains {
                            $0.resting.arrangement.app != nil
                        },
                        style: look
                    )
                {
                    spaceBarsShown.append(bar)
                }
            }
        }
        shelves.holdingRelayout {
            appBars.sync(appBarsShown)
            spaceBars.sync(spaceBarsShown)
        }
        // The pocket wears the shelf's look, and its section rides
        // the shelf: synced first, so each shelf mounts this pass's
        // pocket (#2678).
        pocketPlate.standingDown = standingDown
        pocketPlate.markBands = hiding.pocketBands
        pocketPlate.barStrips = pocketStrips
        // This pass's place, never the last pass's slot (#3432).
        pocketPlate.slots = pocketSlots
        filePocketApproaches(into: &hiding)
        updatePocketPlate()
        // The revealer first, so the shelves judge this pass's
        // hiding edges (#761).
        syncHidingShelves(hiding)
        syncShelves(strips, settings: settings)
        // Every area, and the whole area 0 a screen with no
        // placement record drew.
        let live = Set(state.workspaces.allPlacements.map(\.id)).union(
            displays.map { state.workspaces.placementOrWhole(of: $0.id) }
        )
        retireDepartedBars(live: live)
        // KiwiVision stands down where the shelf does, never for a
        // maximize (#2103, #3061, #3346).
        noteVisionStandDown(standingDown)
        // The overflow marks wear the shelf's look, so they repaint
        // with every shelf repaint, on this pass's verdict (#2235).
        overflowMarks.standingDown = marksStandingDown
        updateOverflowMarks()
    }

    /// Drops the bar overlays of areas outside `live` — after the
    /// shelves are synced, so a departed area whose shelf is still
    /// fading is spared until that fade lands: dropped mid-fade, a
    /// display re-enumerating inside the glide would re-join as a
    /// new section (#1838). The pocket's plate stands per screen.
    private func retireDepartedBars(live: Set<PlacementID>) {
        let keep = live.union(shelves.leavingPlacements)
        appBars.retire(except: keep)
        spaceBars.retire(except: keep)
        pocketPlate.retire(except: keep)
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
                    placement: shelf.placement,
                    edge: shelf.edge,
                    strip: shelf.strip,
                    shelf: settings.kiwishelf,
                    sheen: settings.borderStyle.sheen,
                    space: shelf.carriesSpace
                        ? spaceBars.shownOverlay(on: shelf.placement) : nil,
                    app: shelf.carriesApp
                        ? appBars.shownOverlay(on: shelf.placement) : nil,
                    divider: shelf.divider,
                    slides: shelf.slides,
                    mark: shelf.mark,
                    pocket: shelf.pocketSlot.flatMap { slot in
                        pocketPlate.sectionMount(
                            on: shelf.placement.display
                        ).map {
                            ShelfPocketPiece.Mount(view: $0, slot: slot)
                        }
                    }
                )
            }
        )
    }
}
