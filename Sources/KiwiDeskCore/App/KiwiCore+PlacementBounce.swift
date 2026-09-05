import AppKit
import Foundation

/// The placement-bounce distrust (#1161): an app answering where
/// KiwiDesk just PUT its window with a focus of its own, in a
/// cmd-tab's shape. The ruling and the measurements are in
/// `docs/design-decisions.md`; the obligations in
/// state-and-layout.md. Split from `KiwiCore+FocusEvents` at the
/// §2.1 ceiling; that handler consults `placementBounce` once and
/// answers through `reassertAgainstPlacementBounce`.
extension KiwiCore {
    /// The placement a clickless report for `id` is its app's
    /// reaction to, nil where it is not: an entry of ours within
    /// `PlacementLedger.echoWindow`, no click reached the window,
    /// and one of two arms. In the ACTIVE scrolling Space any of
    /// three discriminators: the placement lies past the screen's
    /// edge; KiwiDesk itself raised the window inside the window
    /// (the self ledger's longer reading); or a focus command
    /// moved focus OFF the window inside it — the app answering
    /// the loss, which no frame ask precedes once its size bound
    /// is learned. Anywhere else — where a clickless focus is how
    /// a user REACHES a parked window — the placement lies past
    /// the edge AND the window refused it by origin.
    func placementBounce(_ id: WindowID, now: Date) -> CGRect? {
        guard let placed = tiler.placements.recent(id, at: now),
            !recentClickReached(id, now: now),
            let actual = state.windows[id]?.frame
        else { return nil }
        let tolerance = TilingEngine.retileTolerance
        let crossesEdge = placementCrossesEdge(placed, of: id)
        if let space = state.workspaces.space(of: id),
            space == state.workspaces.activeSpace,
            state.workspaces[space]?.mode == .scrolling
        {
            let raisedByUs = raisedWithinPlacementWindow(id, now: now)
            let displaced = tiler.placements.recentDisplacement(
                id,
                at: now
            )
            return crossesEdge || raisedByUs || displaced
                ? placed : nil
        }
        let originRefused =
            abs(actual.minX - placed.minX) > tolerance
            || abs(actual.minY - placed.minY) > tolerance
        return crossesEdge && originRefused ? placed : nil
    }

    /// Keeps state on `intended` and re-asserts it with a DIRECT,
    /// unstamped raise — the #465 sibling-distrust shape: the app
    /// took key focus, so a state-only revert would split
    /// keystrokes from the ring, and the raise moves nothing, so
    /// it provokes no second bounce. Renews the placement through
    /// the ledger's bounded door, so a still-reacting app stays
    /// distrusted while the chain still ends.
    func reassertAgainstPlacementBounce(
        _ id: WindowID,
        intended: WindowID,
        placed: CGRect,
        now: Date
    ) {
        tiler.placements.renew(id, at: now)
        onLog(
            "focus: w\(id.raw) placement bounce distrusted; "
                + "re-asserting w\(intended.raw)"
        )
        if let space = state.workspaces.space(of: intended) {
            state.workspaces.focus(intended, in: space)
        }
        if let window = state.windows[intended],
            let element = eventLoop.element(for: intended)
        {
            AXHelper.raise(element, pid: window.pid)
        }
        updateBorders()
        updateStickyMarks()
    }
}
