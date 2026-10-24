import CoreGraphics
import Foundation

/// What a focus key met at its last window that way (#2493): the
/// press, the setting it acts under and where it stood.
struct FocusEdge {
    let args: [JSONValue]
    let direction: Direction
    let mode: FocusWrap
    let space: Space
    let focused: WindowID
    /// The focused window's slot, or its frame for a float.
    let frame: CGRect
    /// The tiled windows the search looked at, in their slots.
    let candidates: [(WindowID, CGRect)]
    /// The pointer's say on a wrap within the screen; a hop always
    /// hands it over (#2548), and no caller passing false reaches
    /// one, the scroll gesture reading All screens as This screen.
    let warp: Bool
    let origin: WindowID?
}

extension KiwiCore {
    /// Focus past the last window that way (#2493). Off answers
    /// nothing, leaving the caller's dead end; This screen wraps to
    /// the window nearest the opposite edge; All screens hops to
    /// the nearest screen that way showing a window, wrapping round
    /// its band, and wraps this screen where no other one has one.
    /// A layout's own steps reach this only past the end of their
    /// order, a run's hidden windows included (#2235).
    func focusPastEdge(_ edge: FocusEdge) -> CommandResponse? {
        switch edge.mode {
        case .off:
            return nil
        case .thisScreen:
            return wrapThisScreen(edge)
        case .allScreens:
            if let hop = hopScreens(
                from: edge.space.id,
                in: edge.direction,
                band: edge.frame
            ) {
                return hop
            }
            return navigate(
                edge.args,
                swapping: false,
                warp: edge.warp,
                origin: edge.origin,
                wrap: .thisScreen
            )
        }
    }

    /// The geometric wrap: the window nearest the edge opposite
    /// the press, in the focused window's band, seeded through
    /// `Navigation.neighbor` — BSP, Stack and Grid alone, the
    /// array-order layouts wrapping in their own steps.
    private func wrapThisScreen(_ edge: FocusEdge) -> CommandResponse? {
        guard [.bsp, .stack, .grid].contains(edge.space.mode) else {
            return nil
        }
        let others = edge.candidates.filter { $0.0 != edge.focused }
        let bounds =
            screenFrame(of: edge.space.id)
            ?? others.reduce(edge.frame) { $0.union($1.1) }
        let seed = ScreenHop.entrySeed(
            into: bounds,
            entering: edge.direction,
            band: edge.frame
        )
        guard
            let target = Navigation.neighbor(
                from: seed,
                in: edge.direction,
                candidates: others
            )
        else { return nil }
        focusWindow(target, warp: edge.warp)
        return .ok()
    }

    /// A focus key on an empty Space, which has no window to step
    /// from: the hop `emptySpaceHop` names, else nil.
    func hopFromEmptySpace(
        _ space: Space,
        in direction: Direction,
        wrap: FocusWrap?
    ) -> CommandResponse? {
        guard let hop = emptySpaceHop(space, in: direction, wrap: wrap)
        else { return nil }
        followSwitch(to: hop.space, focusing: hop.window)
        return .ok()
    }

    /// Where a focus key on an empty Space lands: under All screens,
    /// a hop with its whole screen as the band; nil otherwise or
    /// with nowhere to land. The one answer the #292 preflight and
    /// `navigate` both read.
    func emptySpaceHop(
        _ space: Space,
        in direction: Direction,
        wrap: FocusWrap?
    ) -> (space: SpaceID, window: WindowID)? {
        guard (wrap ?? focusWrap.mode) == .allScreens,
            let band = screenFrame(of: space.id)
        else { return nil }
        return hopTarget(from: space.id, in: direction, band: band)
    }

    /// The hop, switched to through the one `followSwitch`, which
    /// raises, focuses and hands the pointer over (#2548).
    private func hopScreens(
        from origin: SpaceID,
        in direction: Direction,
        band: CGRect
    ) -> CommandResponse? {
        guard let hop = hopTarget(from: origin, in: direction, band: band)
        else { return nil }
        followSwitch(to: hop.space, focusing: hop.window)
        return .ok()
    }

    /// The first screen in `hopOrder` whose shown Space has a window
    /// to land on, and that window.
    private func hopTarget(
        from origin: SpaceID,
        in direction: Direction,
        band: CGRect
    ) -> (space: SpaceID, window: WindowID)? {
        guard let here = state.workspaces.display(of: origin)
        else { return nil }
        let screens = tiler.displayFrames()
        let order = ScreenHop.hopOrder(
            from: here,
            in: direction,
            band: band,
            among: screens
        )
        for display in order {
            guard
                let shown = state.workspaces.activeSpace(on: display),
                shown != origin,
                let space = state.workspaces[shown],
                let bounds = screens.first(where: { $0.id == display })?
                    .frame,
                let landing = landing(
                    in: space,
                    entering: direction,
                    band: band,
                    bounds: bounds
                )
            else { continue }
            return (shown, landing)
        }
        return nil
    }

    /// Where a hop lands on `space`: an array layout's end of order
    /// on the entering side, else the window nearest the entering
    /// edge at the band's cross position — the whole screen's where
    /// the band meets none. A lens's skipped windows and a run's
    /// hidden ones are never landed on; a Space with no tiled
    /// window offers its floats.
    func landing(
        in space: Space,
        entering direction: Direction,
        band: CGRect,
        bounds: CGRect
    ) -> WindowID? {
        let skip = lensKeySkip() ?? { _ in false }
        let hidden = runHidden
        let tiled = state.effectiveTiledMembers(of: space)
            .filter { !skip($0) && !hidden.contains($0) }
        if let end = orderEnd(of: space, tiled, entering: direction) {
            return end
        }
        // The slot, else the last known frame — `navigate`'s rule.
        let slots = shownSlots()
        var candidates = tiled.compactMap { id in
            (slots[id] ?? state.windows[id]?.frame).map { (id, $0) }
        }
        if candidates.isEmpty {
            candidates = state.floatingFocusCandidates(of: space)
                .filter { !skip($0) }
                .compactMap { id in
                    state.windows[id].map { (id, $0.frame) }
                }
                .filter { !$0.1.isEmpty }
        }
        for seedBand in [band, bounds] {
            let seed = ScreenHop.entrySeed(
                into: bounds,
                entering: direction,
                band: seedBand
            )
            if let found = Navigation.neighbor(
                from: seed,
                in: direction,
                candidates: candidates
            ) {
                return found
            }
        }
        return nil
    }

    /// Scrolling's and Monocle's end of order on the side a step
    /// along their axis enters from; nil across it and for every
    /// other layout.
    private func orderEnd(
        of space: Space,
        _ tiled: [WindowID],
        entering direction: Direction
    ) -> WindowID? {
        let horizontal: Bool
        switch space.mode {
        case .scrolling:
            horizontal =
                tiler.settings.resolvedScrolling(for: space.id)
                .orientation == .horizontal
        case .monocle:
            horizontal =
                tiler.settings.resolvedMonocle(for: space.id)
                .orientation == .horizontal
        default:
            return nil
        }
        switch direction {
        case .right where horizontal, .down where !horizontal:
            return tiled.first
        case .left where horizontal, .up where !horizontal:
            return tiled.last
        default:
            return nil
        }
    }

    /// The AX visible frame of the screen `space` lays out on.
    func screenFrame(of space: SpaceID) -> CGRect? {
        state.workspaces.display(of: space).flatMap(handoffScreenFrame)
    }
}
