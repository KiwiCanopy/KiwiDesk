import Foundation

/// The `.windowRekeyed` side effects — retargeting every
/// id-keyed ledger onto a native tab switch's fresh id (#308).
/// Split from `KiwiCore+Events.swift` (350-line ceiling, §2);
/// called only from `handle`.
extension KiwiCore {
    /// A native-tab active-tab change: the state fold already
    /// moved the slot's id (position, focus, weights). The OS
    /// made the new tab frontmost itself, so we must NOT raise
    /// — that is the focus jump we are fixing. Retarget our own
    /// id-keyed bookkeeping; the retile after this refreshes the
    /// ring, App Bar, and frames onto the new id (#308).
    func handleWindowRekeyed(
        old: WindowID,
        new: WindowID
    ) {
        if outstandingSelfRaises.remove(old) != nil {
            outstandingSelfRaises.insert(new)
        }
        if let stamp = selfRaiseStamps.removeValue(
            forKey: old
        ) {
            selfRaiseStamps[new] = stamp
        }
        if let stamp = zOrderRaiseEchoes.removeValue(
            forKey: old
        ) {
            zOrderRaiseEchoes[new] = stamp
        }
        if pendingFocusRaise == old {
            pendingFocusRaise = new
        }
        // The move-intent latch is id-keyed bookkeeping too
        // (#482): its window may still hold OS key focus, so
        // its re-report can arrive under the fresh id.
        moveLatch.rekey(old: old, new: new)
        // A stashed floating window's captured frame must
        // follow the re-key too, or the restore sweep drops
        // it and the window stays parked at the stash
        // corner forever — #412's "floating vanishes"
        // failure mode, reintroduced on this one path.
        tiler.rekeyStash(oldID: old, newID: new)
        // The learned size bound follows the id swap too
        // (#677): same on-screen window, same app-side
        // constraint, new id. So does the monocle
        // shown-member hold (#881) — a tab switch on the
        // shown member must not park it.
        tiler.rekeySizeBound(oldID: old, newID: new)
        tiler.rekeyMonocleShown(oldID: old, newID: new)
        // A live display crossing's bookkeeping (#504) must
        // follow the id swap, or a rekey after a crossing
        // strands the (new) window on the destination space
        // with no record to revert from. Transfer FIRST —
        // cancelDrag(old) then finds nothing under the old
        // id — and revert under the new one: the gesture is
        // aborted, so the window goes home like any other
        // abnormal end.
        dragCrossing.rekey(old: old, new: new)
        cancelDrag(old)
        revertLiveCrossing(new)
    }
}
