import CoreGraphics

/// Ambient direct frame writes wait for the hand to rest (#2627),
/// as an ambient layout pass does (#804): the window is owed,
/// never its frame, and the pass that runs re-derives the write
/// from the window as it then is.
extension KiwiCore {
    /// The one door an ambient writer owes through: it owes `write`
    /// for `id` only while the motion gate holds, and returns
    /// whether it did, so the caller writes when it did not.
    func oweAmbientWrite(
        _ write: MotionGate.OwedWrite,
        for id: WindowID
    ) -> Bool {
        guard tiler.motionGate.owe(write, for: id) else { return false }
        onLog("direct write held: w\(id.raw)")
        return true
    }

    /// Pays every owed write still due, from the pass that runs,
    /// ahead of its layout and so against the strips the last pass
    /// painted: a pass that changes the shelf on that screen lets
    /// the bar clamp move the placement once more. A placement no
    /// longer due falls through to an owed re-anchor.
    func payOwedWrites() {
        tiler.motionGate.payWrites { id, write in
            switch write {
            case .floatPlacement:
                guard owesPlacement(id) else { return false }
                placeFloating(id)
                return true
            case .reanchor:
                guard let space = state.workspaces.space(of: id) else {
                    return false
                }
                reanchorFloat(id, to: space)
                return true
            }
        }
    }

    /// Places detected float `id` now, or owes it while the gate
    /// holds. A placement that only seeds an unshown Space never
    /// waits.
    func placeDetectedFloat(_ id: WindowID) {
        guard state.windows[id] != nil, !placementIsSeed(id),
            oweAmbientWrite(.floatPlacement, for: id)
        else { return placeFloating(id) }
    }

    /// Whether an owed placement is still due: the window still a
    /// placeable float. One the user dragged meanwhile owes nothing
    /// (`handleDragMove` forgets it); a frame its app or our own
    /// echo moved decides nothing, since a refused ask (#677) and a
    /// hand move read alike.
    private func owesPlacement(_ id: WindowID) -> Bool {
        state.windows[id] != nil
            && detectedFloatPlaceable(id)
            && isEffectiveFloatForPlacement(id)
    }
}
