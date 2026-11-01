import Foundation

/// `toggle_pocket_window` (#2675): marks the focused window — or
/// the one an id names (#2612 ▸ 4) — the pocket window, or unmarks
/// it, tiling it. Marking floats it at the float size as a Float
/// does and leaves it out; `pocket` then pockets and takes out that
/// window alone, marking the focus first where none is marked.
extension KiwiCore {
    func togglePocketWindowCommand(_ args: [JSONValue]) -> CommandResponse {
        _ = emptyPocketIfGone()
        let id: WindowID
        switch commandTarget("toggle_pocket_window", args) {
        case .refused(let response): return response
        case .window(let target): id = target
        }
        guard let window = state.windows[id]
        else { return .fail("no focused window") }
        if let app = state.pocketKeyOwner(of: id) {
            return refuseKeyedPocketWindow(id, app: app)
        }
        if state.pocketPhase(of: id) != nil {
            unmarkPocketWindow(id)
            return .ok()
        }
        let capacity = appWide.pocketCapacity
        guard state.pocketAcceptsMark(capacity) else {
            return refuseSecondPocketWindow(id)
        }
        guard !window.isFullscreen, !window.isTransientOverlay
        else { return .fail("this window cannot be pocketed") }
        markAsPocketWindow(id)
        return .ok()
    }

    /// Makes `id` the pocket window, out where it is, at the float
    /// size there and then (#2672) — the one resize a pocket window
    /// takes, and none for a window already floating (owner, #2675);
    /// a take-out keeps its frame. Out, it is placed where it shows;
    /// the `pocket` fallback files the same frame through
    /// `becomePocketWindow` instead.
    /// `owner` ties it to its app's Pocket key (#2612); an arrival
    /// passes `retiling: false`, its event retile being the pass.
    func markAsPocketWindow(
        _ id: WindowID,
        owner: String? = nil,
        retiling: Bool = true
    ) {
        let wasFloating = isEffectiveFloatForPlacement(id)
        guard state.markPocketWindow(id, owner: owner) else { return }
        onLog("pocket: w\(id.raw) marked")
        refreshStickyReach()
        if retiling { retile() }
        if !wasFloating { placeFloating(id) }
    }

    /// Empties `id`'s slot and tiles it on the active Space, as a
    /// Tile does (owner, #2680); a window detection floats stays a
    /// float. Only an out window holds the focus the verb reads.
    func unmarkPocketWindow(_ id: WindowID) {
        state.releasePocketWindow(id)
        // Out, it drew on every Space; it stays on the one shown.
        let home = state.workspaces.space(of: id)
        if let active = state.workspaces.activeSpace, home != active {
            fileMembership(id, into: active, from: home)
        }
        onLog("pocket: w\(id.raw) unmarked")
        refreshStickyReach()
        guard tileRefusal(of: id) == nil else { return retile() }
        _ = setFloating(id, false)
    }

    /// A second window asked to be the pocket window: refused on it.
    func refuseSecondPocketWindow(
        _ id: WindowID
    ) -> CommandResponse {
        soundIfDrawn(
            flashRefusalPill(
                id,
                text: PocketRefusal.markedElsewhereSentence,
                symbol: PocketMark.takenName,
                announce: true
            )
        )
        return .fail("another window is the pocket window")
    }
}
