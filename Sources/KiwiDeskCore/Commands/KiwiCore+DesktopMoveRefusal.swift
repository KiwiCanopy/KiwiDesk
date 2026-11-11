import Foundation

/// What a Desktop move owes the window itself (#2888), split from
/// `KiwiCore+DesktopMove.swift` at the §2.1 target.
extension KiwiCore {
    nonisolated static let pocketedMoveRefusal =
        "a pocketed window cannot change Desktop"
    nonisolated static let outPocketMoveRefusal =
        "a pocket window cannot change Desktop"

    /// The refusal of a window no Desktop move may take, in either
    /// form of the verb, ahead of the Space parse. A pocketed
    /// window is filed nowhere (#2446), an out one is carried back
    /// by `stickyReachCarried` whatever the move does, and a
    /// full-screen one has its own macOS Space (#670).
    func desktopMoveRefusal(_ window: WindowID) -> CommandResponse? {
        switch state.pocketPhase(of: window) {
        case .pocketed:
            return .fail(Self.pocketedMoveRefusal)
        case .out:
            soundIfDrawn(
                flashRefusalPill(
                    window,
                    text: PocketRefusal.desktopMoveSentence,
                    symbol: AutoFloatReason.pocket.pillSymbol,
                    announce: true
                )
            )
            return .fail(Self.outPocketMoveRefusal)
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
        return .fail("a full-screen window cannot change Desktop")
    }

    /// Takes focus for a window a shown Desktop's move filed into
    /// the active Space from where it held none, as `move_to_space`
    /// does: the filing stamped the state focus with no raise, and
    /// the split would fail the next focused verb's #292 preflight.
    /// `leaving` is the anchor read before that filing. Every other
    /// move changes no focus.
    func focusIfFiledIntoActiveSpace(
        _ window: WindowID,
        from: SpaceID?,
        leaving: WindowID?,
        target: DesktopTarget
    ) {
        guard window != leaving, target.isCurrent,
            let destination = state.workspaces.space(of: window),
            destination != from,
            destination == state.workspaces.activeSpace
        else { return }
        focusWindow(
            window,
            refocusRetile: false,
            warp: true,
            leaving: leaving
        )
    }
}
