import CoreGraphics

/// A detection flip's float placement waits for the hand to rest
/// (#2627), as an ambient layout pass does (#804): the window is
/// owed, never its frame, and the pass that runs re-derives the
/// placement from the window as it then is.
extension KiwiCore {
    /// Places detected float `id` now, or owes it to the next pass
    /// that runs while the motion gate holds. A placement on an
    /// unshown Space is only a seed and never waits.
    func placeDetectedFloat(_ id: WindowID) {
        let gate = tiler.motionGate
        guard gate.holdsNow,
            let window = state.windows[id],
            let space = floatPlacementSpace(of: id),
            state.workspaces.visibleSpaces.contains(space)
        else { return placeFloating(id) }
        gate.owedPlacements[id] = window.frame
        onLog("float placement held: \(id)")
        // The release that pays the debt is armed by an owed pass.
        if gate.owed == nil { retile() }
    }

    /// Pays every owed placement still due, from the pass that
    /// runs. A window gone, tiled again, fullscreen, dragged, or
    /// moved off the frame it was owed at keeps where it is.
    func payOwedFloatPlacements() {
        let owed = tiler.motionGate.owedPlacements
        guard !owed.isEmpty else { return }
        tiler.motionGate.owedPlacements = [:]
        for (id, frame) in owed where owesPlacement(id, at: frame) {
            placeFloating(id)
        }
    }

    private func owesPlacement(_ id: WindowID, at frame: CGRect) -> Bool {
        guard let window = state.windows[id],
            !defersEventRetiles,
            seedsPlacement(id),
            isEffectiveFloatForPlacement(id)
        else { return false }
        return TilingEngine.close(window.frame, to: frame)
    }
}
