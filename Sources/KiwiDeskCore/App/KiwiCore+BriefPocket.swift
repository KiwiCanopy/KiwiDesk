import AppKit

/// The brief pocket's door (#2680): a window going into the pocket
/// or out plays it under "Animate float, Pocket & maximize", never
/// under Reduce Motion. The window itself parks at once and comes
/// back with one write.
extension KiwiCore {
    /// Plays the brief pocket for `id` flying `direction`, between
    /// `frame` (AX) and the pocket on the screen `display` names.
    /// The play's timeline from now, nil where nothing plays.
    @discardableResult
    func playBriefPocket(
        _ direction: BriefPocketPlan.Direction,
        window id: WindowID,
        frame: CGRect,
        on display: DisplayID?
    ) -> BriefPocketPlan.Timeline? {
        guard tiler.settings.animations.onStateChange,
            !briefPocket.reduceMotion(),
            let display,
            let screen = TilingEngine.screen(for: display)
        else { return nil }
        let style = tiler.settings.pocketStyle
        let region = pocketRegion(on: display, screen: screen)
        let glass = briefPocketPlateGlass()
        let flight = BriefPocketPlan.flight(
            durationMS: tiler.settings.animations.durationMS
        )
        briefPocket.play(
            BriefPocketOverlay.Request(
                display: display,
                screen: screen,
                direction: direction,
                window: frame,
                pocket: BriefPocketPlan.pocketFrame(
                    in: region,
                    edge: style.edge,
                    position: style.position
                ),
                iconPid: state.windows[id]?.pid,
                shelf: briefPocketShelf(),
                markHex: style.color,
                plateGlass: glass,
                plateTint: tiler.settings.panelsWearFill(glassDrawn: glass)
                    ? tiler.settings.kiwishelf.glassFill : nil,
                flight: flight
            )
        )
        onLog("pocket: w\(id.raw) brief pocket \(direction)")
        return BriefPocketPlan.timeline(direction, flight: flight)
    }

    /// Pays a pocket press's focus hand-off `hand` once the play
    /// `ends` seconds on is over, so no app activates while the
    /// plate draws (#2703); at once where nothing plays. A later
    /// press replaces it, a nil `hand` only cancels, and it is
    /// dropped where the state focus or the Space moved meanwhile.
    func handPocketFocus(
        after ends: TimeInterval?,
        _ hand: (@MainActor () -> Void)?
    ) {
        deferred.cancel(.pocketFocus)
        guard let hand else { return }
        guard let ends else { return hand() }
        let held = state.workspaces.lastFocused
        let space = state.workspaces.activeSpace
        deferred.schedule(.pocketFocus, after: .seconds(ends)) {
            [weak self] in
            guard let self else { return }
            guard self.state.workspaces.activeSpace == space else {
                self.onLog("pocket: landing focus dropped — Space moved")
                return
            }
            guard self.state.workspaces.lastFocused == held else {
                self.onLog("pocket: landing focus dropped — focus moved")
                return
            }
            hand()
        }
    }

    /// The area the pocket sits in on `display`: the screen's
    /// visible bounds, clear of a bar on the pocket's edge, which
    /// keeps it just inside. The brief pocket and the plate (#2678)
    /// read this one region.
    func pocketRegion(on display: DisplayID, screen: NSScreen) -> CGRect {
        let edge = tiler.settings.pocketStyle.edge
        var region = tiler.visibleBounds(screen)
        if let space = state.workspaces.currentSpace(on: display) {
            for (strip, side) in paintedStrips(forSpace: space)
            where side == edge {
                region = AppBarGeometry.regionClear(
                    region,
                    of: strip,
                    edge: side
                )
            }
        }
        return region
    }

    /// The plate is the Space switch's, so it follows KiwiHub's
    /// leaf of the Liquid Glass switch as those plates do.
    func briefPocketPlateGlass() -> Bool {
        LiquidGlassGate.rendered(
            glass: tiler.settings.shortcutPanelLiquidGlass
        )
    }

    /// The pocket wears KiwiShelf's look as drawn, as the overflow
    /// mark does.
    func briefPocketShelf() -> KiwiShelf {
        LiquidGlassGate.rendered(tiler.settings.kiwishelf)
    }
}
