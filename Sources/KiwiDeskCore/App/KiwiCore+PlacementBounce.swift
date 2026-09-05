import AppKit
import Foundation

/// The placement-bounce distrust (#1161): an app answering where
/// KiwiDesk just PUT its window with a focus of its own, in a
/// cmd-tab's shape. Measured 2026-09-05 on the Android Emulator
/// — the sitting is on the issue, the ruling in
/// `docs/design-decisions.md`. Split from `KiwiCore+FocusEvents`
/// at the §2.1 ceiling; that handler consults `placementBounce`
/// once and answers through `reassertAgainstPlacementBounce`.
extension KiwiCore {
    /// Whether a clickless report for `id` is its app's reaction
    /// to a placement of ours within `PlacementLedger.echoWindow`
    /// that lies past the edge of the screen its space lays out
    /// on. In the SCROLLING void the placement is the whole
    /// verdict — the emulator complied within 9 pt of a pan past
    /// the edge and bounced regardless. Anywhere else — the stash
    /// corner of a hidden Space, monocle's park, where a clickless
    /// focus is how a user REACHES an off-screen window — the
    /// window must also have REFUSED the placement, its origin
    /// off the placement's, or that cmd-tab would be eaten.
    func placementBounce(_ id: WindowID, now: Date) -> Bool {
        guard let placed = tiler.placements.recent(id, at: now),
            placementCrossesEdge(placed, of: id),
            !recentClickReached(id, now: now)
        else { return false }
        if let space = state.workspaces.space(of: id),
            space == state.workspaces.activeSpace,
            state.workspaces[space]?.mode == .scrolling
        {
            return true
        }
        guard let actual = state.windows[id]?.frame else {
            return false
        }
        let tolerance = TilingEngine.retileTolerance
        return abs(actual.minX - placed.minX) > tolerance
            || abs(actual.minY - placed.minY) > tolerance
    }

    /// Keeps state on `intended` and re-asserts it with a DIRECT,
    /// unstamped raise — the #465 sibling-distrust shape, because
    /// the app genuinely took key focus and a state-only revert
    /// would split keystrokes from the ring; the raise moves
    /// nothing, so it provokes no second bounce.
    func reassertAgainstPlacementBounce(
        _ id: WindowID,
        intended: WindowID
    ) {
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
