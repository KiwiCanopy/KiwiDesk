import CoreGraphics

/// Ambient direct frame writes wait for the hand to rest (#2627),
/// as an ambient layout pass does (#804): the window is owed,
/// never its frame, and the pass that runs re-derives the write
/// from the window as it then is.
extension KiwiCore {
    /// The one door an ambient writer owes through while the motion
    /// gate holds; the gate holds a pass of its own to pay it when
    /// none is owed, so a caller inside a pass re-enters nothing.
    func oweAmbientWrite(
        _ write: MotionGate.OwedWrite,
        for id: WindowID
    ) {
        tiler.motionGate.owe(write, for: id)
        onLog("direct write held: w\(id.raw)")
    }

    /// Pays every owed write still due, from the pass that runs,
    /// ahead of its layout and so against the strips the last pass
    /// painted: a pass that changes the shelf on that screen lets
    /// the bar clamp move the placement once more.
    func payOwedWrites() {
        for (id, write) in tiler.motionGate.takeWrites() {
            switch write {
            case .floatPlacement:
                if owesPlacement(id) { placeFloating(id) }
            case .reanchor:
                if let space = state.workspaces.space(of: id) {
                    reanchorFloat(id, to: space)
                }
            }
        }
    }

    /// Places detected float `id` now, or owes it while the gate
    /// holds. A placement that only seeds an unshown Space never
    /// waits.
    func placeDetectedFloat(_ id: WindowID) {
        guard tiler.motionGate.holdsNow,
            state.windows[id] != nil,
            !placementIsSeed(id)
        else { return placeFloating(id) }
        oweAmbientWrite(.floatPlacement, for: id)
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
