import Foundation

/// The close-return z-order arm, split out of KiwiCore+Events.swift
/// at the §2.1 ceiling.
///
/// It is not event dispatch: the close handler calls it, but what
/// it does is arm the restack that keeps an overflowing pile
/// stacked for the order the close left behind. Keeping it beside
/// the `handle(_:)` switch made that switch harder to read than
/// it needed to be.
extension KiwiCore {
    /// `ZOrderCloseReturnArmTests` proves the arm directly.
    func armCloseReturnRestack(
        to target: WindowID,
        fromRemovedSlot slot: Int?
    ) {
        guard let slot, let space = activeSpace else { return }
        let tiled = state.effectiveTiledMembers(
            of: space,
            activeSpace: space.id
        )
        guard !tiled.isEmpty,
            let targetIndex = tiled.firstIndex(of: target)
        else { return }
        let from = min(slot, tiled.count - 1)
        if abs(targetIndex - from) > 1 {
            scheduleScrollingZOrderRestoreIfOverflowing()
        }
    }
}
