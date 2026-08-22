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
    /// #674, the close path: a close-return pick can cross
    /// several scrolling slots, and `focusWindow`'s own jump arm
    /// cannot see it — the destroy fold already wrote the pick
    /// into `space.focused`, so the anchor the jump test
    /// classifies from IS the target (distance zero), and the
    /// closed window has left the row besides. Re-derive the
    /// distance from the REMOVED slot instead: the old focus sat
    /// there, and the successor pick inherits it, which is why
    /// the close path never jumped before close-return existed.
    /// The same anchor blindness means the #143 backward-pan
    /// deferral can never defer this raise; that stays the
    /// close-handoff's documented immediate-raise behavior
    /// (`focusWindow`'s own comment), a pop being cheaper than a
    /// spurious deferral on every close. Self-gated downstream on
    /// scrolling + actual overflow; a nil slot (the closed window
    /// was a float or fullscreen member) or a candidate outside
    /// the tiled row is no evidence of a jump — same asymmetry
    /// as `scrollFocusJumpsSlots`. Internal, not private: its
    /// call site (the close handler in `KiwiCore+Events`) sits
    /// behind `eventLoop.isListed` (live AX — the
    /// `TransientOverlayFocusTests` gate note), so
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

extension KiwiCore {
    /// The forgetting both gone-window paths owe (#152/#158):
    /// WindowIDs are reused, so an unechoed self-raise, a
    /// pending z-order echo, the learned size bound, the
    /// monocle shown-member hold and the commanded stamp
    /// (#881) must not reach the next tenant of this id.
    ///
    /// Shared by the destroy and the hide (#913) rather than
    /// copied: the two differ in what they REPORT and in
    /// whether the close-return raise runs, never in what they
    /// forget — and a copy that fell behind would leak exactly
    /// the stale state these lines exist to drop.
    func forgetGoneWindow(_ id: WindowID) {
        outstandingSelfRaises.remove(id)
        zOrderRaiseEchoes[id] = nil
        tiler.forgetSizeBound(id)
        tiler.forgetMonocleShown(id)
        tiler.clearInstantTarget(id)
        cancelDrag(id)
        dragOverlay.hideAll()
    }
}
