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
        let glass = briefPocketPlateGlass()
        let flight = BriefPocketPlan.flight(
            durationMS: tiler.settings.animations.durationMS
        )
        let timeline = BriefPocketPlan.timeline(direction, flight: flight)
        // Held out first, so the pocket stands where the play lands.
        holdPocketOut(on: display, for: timeline.end)
        guard let pocket = pocketLanding(on: display) else {
            // Nothing to land on: the hold ends with the play.
            pocketPlate.playing[display] = nil
            updateBars()
            return nil
        }
        var request =
            BriefPocketOverlay.Request(
                display: display,
                screen: screen,
                direction: direction,
                window: frame,
                pocket: pocket,
                iconPid: state.windows[id]?.pid,
                markHex: style.color,
                plateGlass: glass,
                plateTint: tiler.settings.panelsWearFill(glassDrawn: glass)
                    ? tiler.settings.kiwishelf.glassFill : nil,
                flight: flight
            )
        // A pocket on this screen is the pocket (#2678).
        request.drawsPocket = briefPocketDrawsPocket(on: display)
        briefPocket.play(request)
        // The play draws no pocket where one stands, so that one
        // lights, and nods as a window lands in it (#2776).
        if !request.drawsPocket {
            let into = direction == .into
            let delay = into ? timeline.nodBegin : 0
            deferred.schedule(.pocketLight, after: .seconds(delay)) {
                [weak self] in
                // A play ended or cut short meanwhile lights nothing.
                guard let self, self.pocketPlate.playing[display] != nil
                else { return }
                self.pocketPlate.light(
                    display,
                    for: into
                        ? PocketPlateOverlay.inHold
                        : PocketPlateOverlay.outHold,
                    nods: into
                )
            }
        }
        onLog("pocket: w\(id.raw) brief pocket \(direction)")
        return timeline
    }

    /// Pays a pocket press's focus hand-off `hand` once the play
    /// `ends` seconds on is over, so no app activates while the
    /// plate draws (#2703); at once where nothing plays. A later
    /// press replaces it, a nil `hand` only cancels, and it is
    /// dropped where the state focus or the Space moved meanwhile —
    /// save a move back onto `left`, the window a take-out left,
    /// which macOS re-reports while its raise waits (#2678).
    func handPocketFocus(
        after ends: TimeInterval?,
        leaving left: WindowID? = nil,
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
            let now = self.state.workspaces.lastFocused
            guard now == held || (left != nil && now == left) else {
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
}
