import Foundation

/// The float verbs (#1810): a window is tiled or floating. A Float
/// records that the user floated it; a Tile clears that record and
/// hands the window back to detection — dialog and panel
/// detection, apps without a Dock icon — and refuses where
/// detection floats it. A float rule only decides how a window
/// starts: a Tile overrules it until the window closes, and a Float
/// ends that (#2975, `KiwiCore+TileOverRule`).
extension KiwiCore {
    /// Why detection floats `id`, or nil where it tiles: read from
    /// the event loop's one verdict, never re-detected beside a
    /// verb. A Tile refuses where the reason `refusesTile`; the bar
    /// menu's row and the refusal pill both read it.
    func tileRefusal(of id: WindowID) -> AutoFloatReason? {
        if state.pocketPhase(of: id) != nil { return .pocket }
        return eventLoop.detectionVerdict(for: id)?.reason
    }

    /// The reason a Tile of `id` refuses, or nil where it tiles:
    /// the bar menu's row.
    func tileRefused(_ id: WindowID) -> AutoFloatReason? {
        tileRefusal(of: id).flatMap { $0.refusesTile ? $0 : nil }
    }

    /// `make_floating` / `make_tiled`: the named window, else the
    /// focused one (#1518).
    func setFloating(
        _ command: String,
        _ args: [JSONValue],
        _ floating: Bool
    ) -> CommandResponse {
        switch commandTarget(command, args) {
        case .refused(let response): return response
        case .window(let window): return setFloating(window, floating)
        }
    }

    /// `toggle_floating` (#221): flips the window's own FLAG, ruled
    /// onto it in the `EffectiveFloat` roster (#1697), through the
    /// same two verbs — so a toggle towards tiled refuses where
    /// `make_tiled` would.
    func toggleFloating(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        switch commandTarget(command, args) {
        case .refused(let response): return response
        case .window(let id):
            guard let window = state.windows[id] else {
                return .fail("no focused window")
            }
            return setFloating(id, !window.isFloating)
        }
    }

    func setFloating(
        _ id: WindowID,
        _ floating: Bool
    ) -> CommandResponse {
        let reason = tileRefusal(of: id)
        if let reason, reason.refusesTile {
            // Detection floats it: a Float has nothing to record.
            guard floating else {
                cueTileRefusal(id, reason)
                return .fail(reason.failure)
            }
            return .ok()
        }
        // A rule floats it: only a Tile over the rule moves anything.
        if reason == .rule, floating, !state.tilesOverRule(id) {
            return .ok()
        }
        // Snapshot before the flip: the placement fires only for
        // a window that was no EFFECTIVE float — a floating-mode
        // member's frame is already the user's (`EffectiveFloat`).
        let wasFloating = isEffectiveFloatForPlacement(id)
        // Read before the flip's retile moves it; kept only where
        // the flip really tiles it — a floating-mode member made
        // tiled still floats (#1675).
        let floatFrame = !floating ? floatFrameToRemember(id) : nil
        if reason == .rule {
            state.setTiledOverRule(id, !floating)
        } else {
            state.setFloating(id, floating)
        }
        if let floatFrame, wasFloating,
            !isEffectiveFloatForPlacement(id)
        {
            state.floatFrames[id] = floatFrame
        }
        retile(stateChange: floating ? [] : [id])
        // Float direction only: the tile direction is the retile's,
        // the window named as the state change (#2676).
        if floating, !wasFloating {
            placeFloating(id, asStateChange: true)
        }
        return .ok()
    }
}
