import AppKit

/// The brief pocket's door (#2680): a window going into the pocket
/// or out plays it under "Animate float, Pocket & maximize", never
/// under Reduce Motion. The window itself parks at once and comes
/// back with one write.
extension KiwiCore {
    /// Plays the brief pocket for `id` flying `direction`, between
    /// `frame` (AX) and the pocket on the screen `display` names.
    /// The seconds until the plate lands, nil where nothing plays.
    @discardableResult
    func playBriefPocket(
        _ direction: BriefPocketPlan.Direction,
        window id: WindowID,
        frame: CGRect,
        on display: DisplayID?
    ) -> TimeInterval? {
        guard tiler.settings.animations.onStateChange,
            !briefPocket.reduceMotion(),
            let display,
            let screen = TilingEngine.screen(for: display)
        else { return nil }
        let style = tiler.settings.pocketStyle
        var region = tiler.visibleBounds(screen)
        // A bar on the pocket's edge keeps it just inside.
        if let space = state.workspaces.currentSpace(on: display) {
            for (strip, edge) in paintedStrips(forSpace: space)
            where edge == style.edge {
                region = AppBarGeometry.regionClear(
                    region,
                    of: strip,
                    edge: edge
                )
            }
        }
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
        return BriefPocketPlan.timeline(direction, flight: flight).flightEnd
    }

    /// Pays a pocket press's focus hand-off `hand` once the plate
    /// lands, `lands` seconds on — at once where nothing plays
    /// (#2703). A focus change activates an app on the main thread
    /// the plate's frames tick on, and stalls it 100–350 ms where
    /// that app is KiwiDesk, whose Settings window redraws whole.
    /// Dropped where the focus or the Space moved meanwhile.
    func handPocketFocus(
        after lands: TimeInterval?,
        _ hand: @escaping @MainActor () -> Void
    ) {
        deferred.cancel(.pocketFocus)
        guard let lands else { return hand() }
        let held = focusedWindowID
        let space = state.workspaces.activeSpace
        deferred.schedule(.pocketFocus, after: .seconds(lands)) {
            [weak self] in
            guard let self else { return }
            guard self.focusedWindowID == held,
                self.state.workspaces.activeSpace == space
            else {
                self.onLog("pocket: landing focus dropped — focus moved")
                return
            }
            hand()
        }
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
