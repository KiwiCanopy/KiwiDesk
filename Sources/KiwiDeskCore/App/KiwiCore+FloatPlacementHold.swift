import CoreGraphics

/// Ambient direct frame writes wait for the hand to rest (#2627),
/// as an ambient layout pass does (#804): the window is owed,
/// never its frame, and the pass that runs re-derives the write
/// from the window as it then is.
extension KiwiCore {
    /// The one door an ambient writer owes through while the motion
    /// gate holds. The release that pays it is armed by an owed
    /// pass, so a write owed with none owes one.
    func oweAmbientWrite(
        _ write: MotionGate.OwedWrite,
        for id: WindowID
    ) {
        tiler.motionGate.owe(write, for: id)
        onLog("direct write held: w\(id.raw)")
        if tiler.motionGate.owed == nil { retile() }
    }

    /// Pays every owed write still due, from the pass that runs.
    func payOwedWrites() {
        for (id, write) in tiler.motionGate.takeWrites() {
            switch write {
            case .floatPlacement(let guardFrame):
                if owesPlacement(id, guardFrame: guardFrame) {
                    placeFloating(id)
                }
            }
        }
    }

    /// Places detected float `id` now, or owes it while the gate
    /// holds. A placement that only seeds an unshown Space never
    /// waits.
    func placeDetectedFloat(_ id: WindowID) {
        guard tiler.motionGate.holdsNow,
            let window = state.windows[id],
            !placementIsSeed(id)
        else { return placeFloating(id) }
        let sent = tiler.commandedFrame(of: id) ?? window.frame
        oweAmbientWrite(.floatPlacement(guardFrame: sent), for: id)
    }

    /// Whether an owed placement is still due: the window still a
    /// placeable float, standing where we last sent it — a window
    /// moved meanwhile, by the user or its app, keeps its frame.
    private func owesPlacement(
        _ id: WindowID,
        guardFrame: CGRect
    ) -> Bool {
        guard let window = state.windows[id],
            detectedFloatPlaceable(id),
            isEffectiveFloatForPlacement(id)
        else { return false }
        return TilingEngine.close(window.frame, to: guardFrame)
    }
}
