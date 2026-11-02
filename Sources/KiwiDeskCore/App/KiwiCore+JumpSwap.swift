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
                refuseJumpSwap(target)
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

    /// Why a Swap here would not trade tracked `window` with
    /// `partner`, by the verb's own verdict, named for the side
    /// that blocks; nil where it trades. The panel words it.
    func jumpSwapBlock(
        _ window: WindowID,
        partner: WindowID?
    ) -> JumpSwapBlock? {
        guard let partner else { return .nothingHere }
        guard let block = swapBlock(window, partner) else { return nil }
        switch block {
        case .sameWindow:
            return .yours
        case .unfiled(let id):
            return id == window && state.isPocketed(id)
                ? .pocketed : .nothingHere
        case .fullScreen(let id):
            return id == window ? .fullScreen : .yoursFullScreen
        case .floating(let id):
            return id == window ? .floating : .yoursFloating
        case .sticky(let id, _):
            return id == window ? .sticky : .yoursSticky
        }
    }

    /// Why Move here would refuse `window`, as `moveHere(_:)`
    /// refuses it; nil where it moves or is already here.
    func jumpMoveBlock(
        _ window: ManagedWindow,
        from space: SpaceID?,
        into here: SpaceID?
    ) -> JumpMoveBlock? {
        // A pocketed window comes out instead (#2446).
        guard let here, space != here, !state.isPocketed(window.id)
        else { return nil }
        if window.isFullscreen { return .fullScreen }
        // A ∞ window is only focused, which no refusal names.
        guard let block = stickyMoveBlock(window.id, to: here),
            block != .global || window.stickyScope != .global
        else { return nil }
        return .sticky
    }

    /// A row no verb can see in this slice — a hidden app, or a
    /// window minimized or on a Desktop no screen shows — cued on
    /// the focused window, where the user is looking.
    private func refuseJumpSwap(_ target: JumpEntry.Target) {
        let refusal = WindowActionRefusal.cannotSwapHere(
            window: jumpRowName(target)
        )
        guard let focused = focusedWindowID else {
            onLog("\(refusal.logReason): \(target)")
            return
        }
        cueWindowAction(refusal, on: focused)
    }

    /// A row's name as Core knows it: its window's title, else its
    /// app's name.
    private func jumpRowName(_ target: JumpEntry.Target) -> String {
        switch target {
        case .hiddenApp(let pid):
            return eventLoop.liveApps(owners: [])
                .first { $0.pid == pid }?.ref.name ?? ""
        case .window(let id):
            if let away = state.awayWindows[id] {
                return away.title.isEmpty ? away.appName : away.title
            }
            if let parked = state.minimizeOrder.first(where: { $0.id == id }) {
                return parked.title.isEmpty ? parked.app : parked.title
            }
            return ""
        }
    }
}
