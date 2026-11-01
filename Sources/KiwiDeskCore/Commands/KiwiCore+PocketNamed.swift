import Foundation

/// `pocket` naming a window (#2678): that window goes in, marked
/// first under the capacity, never the key's next step. The bar
/// menus' Pocket Window row acts through it and greys on the one
/// `pocketNamedRefusal` the handler answers from.
extension KiwiCore {
    /// Why `pocket` naming `id` would refuse it, nil where it is
    /// taken in.
    enum PocketNamedRefusal: Equatable {
        /// One window, another already marked.
        case taken
        /// Untracked, in native full screen, or a transient panel.
        case cannot
    }

    func pocketNamedRefusal(_ id: WindowID) -> PocketNamedRefusal? {
        guard let window = state.windows[id], !window.isFullscreen,
            !window.isTransientOverlay
        else { return .cannot }
        guard state.pocketPhase(of: id) == nil else { return nil }
        let capacity = appWide.pocketCapacity
        return state.pocketAcceptsMark(capacity) ? nil : .taken
    }

    /// `pocket`'s dispatch: a named window, else the key's step.
    func pocketCommand(_ args: [JSONValue]) -> CommandResponse {
        guard namesWindow("pocket", args) else { return pocketCommand() }
        if emptyPocketIfGone() { updatePocketPlate() }
        switch commandTarget("pocket", args) {
        case .refused(let response):
            return response
        case .window(let id):
            if let app = state.pocketKeyOwner(of: id) {
                return refuseKeyedPocketWindow(id, app: app)
            }
            switch pocketNamedRefusal(id) {
            case .taken: return refuseSecondPocketWindow(id)
            case .cannot: return .fail("this window cannot be pocketed")
            case nil: break
            }
            if state.isPocketed(id) { return .ok() }
            if state.pocketPhase(of: id) == .out {
                putInPocket(id)
                return .ok()
            }
            return markAndPocket(id)
        }
    }

    /// Marks `id` and pockets it — the empty pocket's press, and a
    /// named one (#2678).
    func markAndPocket(_ id: WindowID) -> CommandResponse {
        guard let window = state.windows[id] else {
            return .fail("no focused window")
        }
        guard !window.isFullscreen, !window.isTransientOverlay
        else { return .fail("this window cannot be pocketed") }
        // Marked first (#2675), its float frame read while it is
        // still in its Space and filed at the park; a window
        // already floating keeps its own.
        let becoming =
            isEffectiveFloatForPlacement(id)
            ? nil : becomePocketWindow(id)
        guard state.markPocketWindow(id)
        else { return .fail("this window cannot be pocketed") }
        putInPocket(id, filing: becoming)
        return .ok()
    }
}
