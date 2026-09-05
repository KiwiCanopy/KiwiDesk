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
    /// The placement a clickless report for `id` is its app's
    /// reaction to, nil where it is not: a placement of ours
    /// within `PlacementLedger.echoWindow`, no click reached the
    /// window, and one of two arms. In a SCROLLING Space's row the
    /// placement lies past the screen's edge — the emulator
    /// complied within 9 pt of a pan into the void and bounced
    /// regardless — or the app REFUSED the size asked, which a
    /// window sliding to an on-screen slot never does and the
    /// emulator does on every re-ask (device, 2026-09-05 19:03).
    /// Anywhere else — the stash corner of a hidden Space,
    /// monocle's park, where a clickless focus is how a user
    /// REACHES an off-screen window — the placement lies past the
    /// edge AND the window refused it by origin, or that cmd-tab
    /// would be eaten.
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
            let sizeRefused =
                abs(actual.width - placed.width) > tolerance
                || abs(actual.height - placed.height) > tolerance
            return crossesEdge || sizeRefused ? placed : nil
        }
        let originRefused =
            abs(actual.minX - placed.minX) > tolerance
            || abs(actual.minY - placed.minY) > tolerance
        return crossesEdge && originRefused ? placed : nil
    }

    /// Keeps state on `intended` and re-asserts it with a DIRECT,
    /// unstamped raise — the #465 sibling-distrust shape, because
    /// the app genuinely took key focus and a state-only revert
    /// would split keystrokes from the ring; the raise moves
    /// nothing, so it provokes no second bounce. The placement is
    /// RE-STAMPED: the bounce is proof the app is still reacting,
    /// and the emulator's third retry landed past a window that
    /// started at the pan (device, 2026-09-05 19:03) — so an app
    /// that keeps bouncing keeps being bounced until it has been
    /// quiet for the window, while a window that never bounces
    /// still expires at it.
    func reassertAgainstPlacementBounce(
        _ id: WindowID,
        intended: WindowID,
        placed: CGRect
    ) {
        tiler.placements.stamp(id, target: placed)
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
