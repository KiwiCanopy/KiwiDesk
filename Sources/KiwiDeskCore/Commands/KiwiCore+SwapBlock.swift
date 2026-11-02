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
    /// The sticky gate keeps the window out of `space` (#445).
    case sticky(WindowID, into: SpaceID)
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
        for (id, into) in [(lead, away), (partner, home)]
        where stickyMoveBlock(
            id,
            to: into,
            landingOn: landingDisplay(of: into)
        ) != nil {
            return .sticky(id, into: into)
        }
        return nil
    }

    /// Why `id` holds no slot to swap, nil where it does.
    func slotBlock(_ id: WindowID) -> SwapBlock? {
        if state.isPocketed(id) || state.workspaces.space(of: id) == nil {
            return .unfiled(id)
        }
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
            cueWindowAction(.cannotSwapHere(window: windowTitle(id)), on: id)
            return .fail("window is in no Space")
        case .fullScreen(let id):
            cueWindowAction(
                .cannotSwapFullScreen(window: windowTitle(id)),
                on: id
            )
            return .fail("window \(id.raw) is full screen")
        case .floating(let id):
            cueWindowAction(.cannotSwapFloating, on: id)
            return .fail("window \(id.raw) is floating")
        case .sticky(let id, let into):
            // The sticky gate's own pill.
            _ = stickyMoveRefused(
                id,
                to: into,
                landingOn: landingDisplay(of: into)
            )
            return .fail("a sticky window cannot change Space")
        }
    }
}
