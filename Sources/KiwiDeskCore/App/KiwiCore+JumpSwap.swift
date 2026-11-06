import Foundation

/// KiwiHub's Swap here (#2885, slice 1): the picked window takes
/// your slot and the focus, yours takes its slot, and you stay.
/// "Your window" is the focus of the Space the panel's screen
/// shows, as for Move here (#2791), else the global focus. Only a
/// tracked row trades in this slice; every refusal is cued.
extension KiwiCore {
    /// Swaps `target`'s window with yours through the public swap
    /// verbs, so a refusal is the verb's own and the change report
    /// fires. `display` is the screen KiwiHub opened on.
    public func swapHere(
        _ target: JumpEntry.Target,
        on display: DisplayID? = nil
    ) {
        withUserMotion {
            guard case .window(let id) = target, state.windows[id] != nil
            else {
                refuseJumpSwap(target, on: display)
                return
            }
            let here = moveHereSpace(on: display)
            // `swap_here`'s implied window is the active Space's
            // focus (#292), so another screen's is named instead,
            // and the switch to it follows the trade.
            guard let here, here != state.workspaces.activeSpace,
                let mine = jumpHereFocus(in: here)
            else {
                execute("swap_here", args: [.number(Double(id.raw))])
                return
            }
            let swapped = execute(
                "swap",
                args: [.number(Double(id.raw)), .number(Double(mine.raw))]
            )
            guard swapped.isSuccess else { return }
            enterMoveHereSpace(here)
            focusWindow(id, warp: true)
        }
    }

    /// The focus of the Space `here` names, nil where it has none.
    func jumpHereFocus(in here: SpaceID?) -> WindowID? {
        here.flatMap { state.workspaces[$0] }
            .flatMap { state.focusAnchor(of: $0) }
    }

    /// The window a Swap here from `here`'s screen trades with: its
    /// Space's focus, else the global one.
    func jumpSwapPartner(in here: SpaceID?) -> WindowID? {
        jumpHereFocus(in: here) ?? focusedWindowID
    }

    /// A row no verb can see in this slice — a hidden app, or a
    /// window minimized or on a Desktop no screen shows — cued on
    /// the focused window, where the user is looking.
    private func refuseJumpSwap(
        _ target: JumpEntry.Target,
        on display: DisplayID?
    ) {
        let refusal = jumpSwapRefusal(target, on: display)
        guard let focused = focusedWindowID else {
            onLog("\(refusal.logReason): \(target)")
            return
        }
        cueWindowAction(refusal, on: focused)
    }

    /// The pill for a row no verb can see, read off the verdict the
    /// row is drawn by (`swapRefusal`), so the two never disagree.
    private func jumpSwapRefusal(
        _ target: JumpEntry.Target,
        on display: DisplayID?
    ) -> WindowActionRefusal {
        switch swapRefusal(target, on: display) {
        case .hiddenApp: .cannotSwapHiddenApp
        case .minimized: .cannotSwapMinimized
        case .otherDesktop: .cannotSwapHiddenDesktop
        case .fullScreen:
            .cannotSwapFullScreen(window: awayName(target))
        case .yoursFullScreen:
            .cannotSwapFullScreen(
                window: focusedWindowID.map(windowTitle) ?? ""
            )
        default: .cannotSwapGone
        }
    }

    private func awayName(_ target: JumpEntry.Target) -> String {
        guard case .window(let id) = target,
            let away = state.awayWindows[id]
        else { return "" }
        return away.title.isEmpty ? away.appName : away.title
    }
}
