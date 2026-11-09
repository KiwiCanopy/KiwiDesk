import Foundation

/// The refusal every Space move asks of the window itself (#3119),
/// split from `KiwiCore+MoveWindow.swift` at the §2.1 target.
extension KiwiCore {
    /// Why no Space move may take `window`, or nil: a pocketed
    /// window is filed nowhere (#2446), and a full-screen one is
    /// held on its own macOS Space (#3119). Pure, for a gate that
    /// greys; a verb refuses through `spaceMoveRefusal`.
    func spaceMoveBlock(_ window: WindowID) -> SpaceMoveBlock? {
        if state.isPocketed(window) { return .pocketed }
        if state.windows[window]?.isFullscreen == true {
            return .fullScreen
        }
        return nil
    }

    /// `spaceMoveBlock`'s refusal, ahead of the move's target; a
    /// full-screen window's is cued on the window.
    func spaceMoveRefusal(_ window: WindowID) -> CommandResponse? {
        switch spaceMoveBlock(window) {
        case nil:
            return nil
        case .pocketed:
            return .fail("a pocketed window cannot move to a Space")
        case .fullScreen:
            let refusal = WindowActionRefusal.cannotChangeSpaceFullScreen(
                window: windowTitle(window)
            )
            cueWindowAction(refusal, on: window)
            return .fail(refusal.logReason)
        }
    }
}

/// What stands a Space move down for the window itself (#3119).
enum SpaceMoveBlock: Equatable {
    case pocketed
    case fullScreen
}
