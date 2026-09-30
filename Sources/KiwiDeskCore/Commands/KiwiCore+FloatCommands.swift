import Foundation

/// The float verbs (#1810): a window is tiled or floating. A Float
/// records that the user floated it; a Tile clears that record and
/// hands the window back to detection — float rules, dialog and
/// panel detection, apps without a Dock icon — and refuses where
/// detection floats it.
extension KiwiCore {
    /// Why a Tile of `id` would do nothing, or nil where it tiles:
    /// read from the event loop's one verdict, never re-detected
    /// beside a verb. The bar menu's row and the refusal pill both
    /// read it.
    func tileRefusal(of id: WindowID) -> AutoFloatReason? {
        eventLoop.detectionVerdict(for: id)?.reason
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

    private func setFloating(
        _ id: WindowID,
        _ floating: Bool
    ) -> CommandResponse {
        if let reason = tileRefusal(of: id) {
            // Detection floats it: a Float has nothing to record.
            guard floating else {
                cueTileRefusal(id, reason)
                return .fail(reason.failure)
            }
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
        state.setFloating(id, floating)
        if let floatFrame, wasFloating,
            !isEffectiveFloatForPlacement(id)
        {
            state.floatFrames[id] = floatFrame
        }
        retile()
        // Float direction only: `make_tiled` already animates a
        // real move back into the layout.
        if floating, !wasFloating {
            placeFloating(id)
        }
        return .ok()
    }
}
