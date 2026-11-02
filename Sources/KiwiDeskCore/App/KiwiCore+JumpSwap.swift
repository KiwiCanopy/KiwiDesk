import Foundation

/// KiwiHub's Swap here (#2885, slice 1): the picked window takes
/// your slot and the focus, yours takes its slot, and you stay.
/// "Your window" is the focus of the Space the panel's screen
/// shows, as for Move here (#2791), else the global focus. Only a
/// tracked row trades in this slice; every refusal is cued.
extension KiwiCore {
    /// Swaps `entry`'s window with yours through the public swap
    /// verbs, so a refusal is the verb's own and the change report
    /// fires. `display` is the screen KiwiHub opened on.
    public func swapHere(_ entry: JumpEntry, on display: DisplayID? = nil) {
        withUserMotion {
            guard case .window(let id) = entry.target,
                state.windows[id] != nil, !state.isPocketed(id)
            else {
                refuseJumpSwap(entry)
                return
            }
            let here = moveHereSpace(on: display)
            // The verb's implied window is the active Space's focus
            // (#292), so another screen's pair is named instead.
            guard let here, here != state.workspaces.activeSpace,
                let mine = jumpSwapPartner(in: here)
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

    /// The window a Swap here from `here`'s screen trades with: its
    /// Space's focus, else the global one.
    func jumpSwapPartner(in here: SpaceID?) -> WindowID? {
        here.flatMap { state.workspaces[$0] }
            .flatMap { state.focusAnchor(of: $0) }
            ?? focusedWindowID
    }

    /// Whether a Swap here would trade `window` with `partner`: two
    /// tracked windows, each holding a slot, that the sticky gate
    /// lets change Space. The panel draws the swap's route and its
    /// lit hint by it, never by its own reading of the gates.
    func jumpSwapsHere(
        _ window: ManagedWindow,
        partner: WindowID?
    ) -> Bool {
        guard let partner, partner != window.id,
            let mine = state.windows[partner],
            !state.isPocketed(window.id), !state.isPocketed(partner),
            let theirs = state.workspaces.space(of: window.id),
            let ours = state.workspaces.space(of: partner)
        else { return false }
        for side in [window, mine] {
            if side.isFullscreen || isEffectiveFloatForPlacement(side.id) {
                return false
            }
        }
        guard theirs != ours else { return true }
        return stickyMoveBlock(
            window.id,
            to: ours,
            landingOn: landingDisplay(of: ours)
        ) == nil
            && stickyMoveBlock(
                partner,
                to: theirs,
                landingOn: landingDisplay(of: theirs)
            ) == nil
    }

    /// A row this slice reaches no slot for: cued on its window,
    /// else on the focused one, where the user is looking.
    private func refuseJumpSwap(_ entry: JumpEntry) {
        let refusal = WindowActionRefusal.cannotSwapHere(
            window: entry.title.isEmpty ? entry.app : entry.title
        )
        if case .window(let id) = entry.target {
            cueWindowAction(refusal, on: id)
        } else if let focused = focusedWindowID {
            cueWindowAction(refusal, on: focused)
        } else {
            onLog("\(refusal.logReason): \(entry.app)")
        }
    }
}
