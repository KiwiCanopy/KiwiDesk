import Foundation

// MARK: - Monocle's shown-member hold (#881)

/// The anchor-hold half of monocle's `park` hide style, split
/// from `TilingEngine+Layout.swift` (350-line ceiling): while a
/// float holds the focus, the layout keeps showing the member
/// the user was on instead of re-deriving the shown member from
/// the array front and physically swapping windows under the
/// float. The stored map lives on `TilingEngine`
/// (`monocleShownMembers`, the `stashedFrames` precedent).
extension TilingEngine {
    /// The context anchor for one space, with the float-focus
    /// hold applied: while a tiled member is the anchor it is
    /// remembered per space; when the anchor leaves the tiled
    /// set — a focused local float — the remembered member
    /// stands in, validated against membership at read time.
    /// Falls through to the raw anchor when nothing remembered
    /// survives. Monocle-only on purpose: scrolling's anchor
    /// drives a pan whose stability `scrollOffset` already
    /// owns, and no other layout reads `context.focused`.
    func heldMonocleAnchor(
        _ anchor: WindowID?,
        space: Space,
        tiled: [WindowID]
    ) -> WindowID? {
        guard space.mode == .monocle else { return anchor }
        if let anchor, tiled.contains(anchor) {
            monocleShownMembers[space.id] = anchor
            return anchor
        }
        if let held = monocleShownMembers[space.id],
            tiled.contains(held)
        {
            return held
        }
        return anchor
    }

    /// Drops a destroyed window from the hold: WindowIDs are
    /// reused (#152/#158), so a stale entry could pin a future
    /// stranger as the shown member.
    public func forgetMonocleShown(_ id: WindowID) {
        monocleShownMembers = monocleShownMembers.filter {
            $0.value != id
        }
    }

    /// Migrates the hold across a native-tab rekey (#308),
    /// beside `rekeyStash` and `rekeySizeBound`: same on-screen
    /// window, new id.
    public func rekeyMonocleShown(
        oldID: WindowID,
        newID: WindowID
    ) {
        for (space, id) in monocleShownMembers
        where id == oldID {
            monocleShownMembers[space] = newID
        }
    }
}
