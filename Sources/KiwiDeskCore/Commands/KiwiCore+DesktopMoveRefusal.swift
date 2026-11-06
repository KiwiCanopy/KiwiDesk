import Foundation

/// What a Desktop move owes the window itself (#2888), split from
/// `KiwiCore+DesktopMove.swift` at the §2.1 target.
extension KiwiCore {
    /// The refusal of a window no Desktop move may take, in either
    /// form of the verb, ahead of the Space parse. A pocketed
    /// window is filed nowhere (#2446), an out one is carried back
    /// by `stickyReachCarried` whatever the move does, and a
    /// full-screen one has its own macOS Space (#670).
    func desktopMoveRefusal(_ window: WindowID) -> CommandResponse? {
        switch state.pocketPhase(of: window) {
        case .pocketed:
            return .fail("window \(window.raw) is in the pocket")
        case .out:
            soundIfDrawn(
                flashRefusalPill(
                    window,
                    text: PocketRefusal.desktopMoveSentence,
                    symbol: AutoFloatReason.pocket.pillSymbol,
                    announce: true
                )
            )
            return .fail("window \(window.raw) is a pocket window")
        case nil:
            break
        }
        guard state.windows[window]?.isFullscreen == true else {
            return nil
        }
        cueWindowAction(
            .cannotMoveFullScreen(window: windowTitle(window)),
            on: window
        )
        return .fail("window \(window.raw) is full screen")
    }

    /// Whether `window` holds the focus a move leaves alone. A
    /// verb naming no window acts on the anchor, which `lastFocused`
    /// can lag (the #463 hazard `moveWindow` argues).
    func holdsFocus(_ window: WindowID) -> Bool {
        window == focusedWindowID || window == state.workspaces.lastFocused
    }

    /// Takes focus for a named window a shown Desktop's move filed
    /// into the active Space, as `move_to_space` does: the filing
    /// stamped the state focus with no raise, and the split would
    /// fail the next focused verb's #292 preflight. Every other
    /// move changes no focus.
    func focusIfFiledIntoActiveSpace(
        _ window: WindowID,
        from: SpaceID?,
        held: Bool,
        target: DesktopTarget
    ) {
        guard !held, target.isCurrent,
            let destination = state.workspaces.space(of: window),
            destination != from,
            destination == state.workspaces.activeSpace
        else { return }
        focusWindow(window, refocusRetile: false, warp: true)
    }
}
