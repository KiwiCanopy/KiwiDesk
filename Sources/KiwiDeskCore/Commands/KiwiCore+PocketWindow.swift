import Foundation

/// `toggle_pocket_window` (#2675): marks the focused window the
/// pocket window, or unmarks it. Marking floats it at the float
/// size as a Float does and leaves it out; `pocket` then pockets
/// and takes out that window alone, marking the focus first where
/// none is marked.
extension KiwiCore {
    func togglePocketWindowCommand() -> CommandResponse {
        _ = emptyPocketIfGone()
        guard let id = focusedWindowID, let window = state.windows[id]
        else { return .fail("no focused window") }
        if state.pocketPhase(of: id) != nil {
            unmarkPocketWindow(id)
            return .ok()
        }
        if state.pocket != nil { return refuseSecondPocketWindow(id) }
        guard !window.isFullscreen, !window.isTransientOverlay
        else { return .fail("this window cannot be pocketed") }
        markPocketWindow(id)
        return .ok()
    }

    /// Makes `id` the pocket window, out where it is, at the float
    /// size there and then (#2672) — the one resize a pocket window
    /// takes, and none for a window already floating (owner, #2675);
    /// a take-out keeps its frame. Out, it is placed where it shows;
    /// the `pocket` fallback files the same frame through
    /// `becomePocketWindow` instead.
    private func markPocketWindow(_ id: WindowID) {
        let wasFloating = isEffectiveFloatForPlacement(id)
        guard state.markPocketWindow(id) else { return }
        onLog("pocket: w\(id.raw) marked")
        refreshStickyReach()
        retile()
        if !wasFloating { placeFloating(id) }
    }

    /// Empties the slot, leaving `id` a plain float on the active
    /// Space. Only an out window holds the focus the verb reads.
    private func unmarkPocketWindow(_ id: WindowID) {
        state.releasePocketWindow()
        // Out, it drew on every Space; it stays on the one shown.
        let home = state.workspaces.space(of: id)
        if let active = state.workspaces.activeSpace, home != active {
            fileMembership(id, into: active, from: home)
        }
        onLog("pocket: w\(id.raw) unmarked")
        refreshStickyReach()
        retile()
    }

    /// A second window asked to be the pocket window: refused on it.
    private func refuseSecondPocketWindow(
        _ id: WindowID
    ) -> CommandResponse {
        soundIfDrawn(
            flashRefusalPill(
                id,
                text: PocketRefusal.markedElsewhereSentence,
                symbol: AutoFloatReason.pocket.pillSymbol,
                announce: true
            )
        )
        return .fail("another window is the pocket window")
    }
}
