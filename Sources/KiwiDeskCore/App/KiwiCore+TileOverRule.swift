import Foundation

/// A Tile over a float rule (#2975): a rule decides how a window
/// starts, and a Tile keeps that window tiled until it closes. The
/// record is `StateCoordinator.tiledOverRule`; this is its one
/// reader, laid over detection's verdict ahead of the fold, so
/// `EventLoop.autoFloatVerdict` stays the only composition.
extension KiwiCore {
    /// `event` with a Tile over a rule applied: a re-adoption arrives
    /// tiled, and a float verdict the rule gives again is dropped
    /// (nil). A verdict that refuses a Tile ends the record.
    func applyingTileOverRule(_ event: KiwiEvent) -> KiwiEvent? {
        switch event {
        case .windowCreated(var window) where window.isFloating:
            guard tileOverRuleStands(window.id, pid: window.pid) else {
                return event
            }
            window.isFloating = false
            return .windowCreated(window)
        case .windowFloatChanged(let id, isFloating: true):
            // A window a hide dropped is no verdict on its Tile.
            guard let pid = state.windows[id]?.pid else { return event }
            return tileOverRuleStands(id, pid: pid) ? nil : event
        default:
            return event
        }
    }

    /// Whether `id`'s record holds over the floating verdict now:
    /// only a rule's, on `pid` — the arriving window's own, since a
    /// re-adoption is not in state yet — and outside the pocket.
    /// Any other reason ends it.
    private func tileOverRuleStands(_ id: WindowID, pid: pid_t?) -> Bool {
        guard let recorded = state.tiledOverRule[id] else { return false }
        let verdict = tileRefusal(of: id)
        guard recorded == pid, state.pocketPhase(of: id) == nil,
            verdict == .rule
        else {
            state.tiledOverRule[id] = nil
            let reason = verdict.map { $0.wireName } ?? "none"
            onLog(
                "float: w\(id.raw) Tile over a rule ended "
                    + "(reason \(reason), pid \(pid.map(String.init) ?? "-"))"
            )
            return false
        }
        return true
    }

    /// Takes back the Tiles over a rule an in-place stop carried
    /// (#2975), where the rule still floats the window; the
    /// restore's retile draws them.
    func adoptTilesOverRule(_ snapshot: StateSnapshot) {
        for record in snapshot.windows
        where record.session?.tiledOverRule == true
            && state.windows[record.windowID]?.isFloating == true
            && tileRefusal(of: record.windowID) == .rule
        {
            state.setTiledOverRule(record.windowID, true)
        }
    }
}
