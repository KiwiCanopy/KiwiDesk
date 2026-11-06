import Foundation

/// Why a swap would trade nothing (#2509, #2885): the one verdict
/// the swap verbs refuse by and KiwiHub's rows light by, so a gate
/// added here reaches both.
enum SwapBlock: Equatable {
    case sameWindow(WindowID)
    /// Pocketed, or filed in no Space: no slot to trade.
    case unfiled(WindowID)
    /// In native full screen, its own macOS Space (#670).
    case fullScreen(WindowID)
    /// An effective float holds no slot.
    case floating(WindowID)
    /// The sticky gate keeps the window out of a Space (#445);
    /// `scope` is the one its pill names.
    case sticky(WindowID, scope: StickyScope)
}

extension KiwiCore {
    /// The verdict on trading `lead` with `partner`, nil where the
    /// trade goes ahead. Pure: it cues nothing.
    func swapBlock(_ lead: WindowID, _ partner: WindowID) -> SwapBlock? {
        guard lead != partner else { return .sameWindow(lead) }
        for id in [lead, partner] {
            if let block = slotBlock(id) { return block }
        }
        guard let home = state.workspaces.space(of: lead),
            let away = state.workspaces.space(of: partner),
            home != away
        else { return nil }
        for (id, into) in [(lead, away), (partner, home)] {
            if let scope = stickyMoveBlock(
                id,
                to: into,
                landingOn: landingDisplay(of: into)
            ) {
                return .sticky(id, scope: scope)
            }
        }
        return nil
    }

    /// Why `id` holds no slot to swap, nil where it does.
    func slotBlock(_ id: WindowID) -> SwapBlock? {
        // A pocketed window is a member of no Space (#2446).
        if state.workspaces.space(of: id) == nil { return .unfiled(id) }
        if state.windows[id]?.isFullscreen == true { return .fullScreen(id) }
        if isEffectiveFloatForPlacement(id) { return .floating(id) }
        return nil
    }

    /// Cues `block` on its window and answers the verb's refusal,
    /// CLI and KiwiHub alike (#2885 ▸ Ruling 5).
    func refuseSwap(_ block: SwapBlock) -> CommandResponse {
        switch block {
        case .sameWindow(let id):
            cueWindowAction(.swapWithSelf(window: windowTitle(id)), on: id)
            return .fail("cannot swap a window with itself")
        case .unfiled(let id):
            cueWindowAction(
                state.isPocketed(id)
                    ? .cannotSwapPocketed : .cannotSwapUnfiled,
                on: id
            )
            return .fail("window \(id.raw) is in no Space")
        case .fullScreen(let id):
            cueWindowAction(
                .cannotSwapFullScreen(window: windowTitle(id)),
                on: id
            )
            return .fail("full-screen window \(id.raw) cannot be swapped")
        case .floating(let id):
            cueWindowAction(.cannotSwapFloating, on: id)
            return .fail("floating window \(id.raw) cannot be swapped")
        case .sticky(let id, let scope):
            // The sticky gate's own pill.
            flashStickyMoveBlocked(id, scope: scope)
            return .fail("sticky window \(id.raw) cannot change Space")
        }
    }
}
