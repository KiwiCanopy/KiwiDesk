import CoreGraphics

/// A maximized float's way back (#3036). An ender only clears the
/// flag; the frame is paid here, at the tail of `retile()` or by a
/// verb that ends the Maximize before it acts, so no ender owes a
/// write of its own.
extension KiwiCore {
    /// Puts every float whose Maximize ended back at its return
    /// frame — seeded as its pending capture where its Space is not
    /// shown — and drops the record. A window the hand holds, or one
    /// in native full screen, keeps it for a later pass; one that
    /// tiled, entered the pocket or is gone takes none.
    func payMaximizedFloatReturns() {
        for (id, saved) in state.owedMaximizedFloatReturns() {
            guard let window = state.windows[id] else { continue }
            if tiler.dragExemptWindow == id || window.isFullscreen {
                continue
            }
            state.maximizedFloatReturn[id] = nil
            guard window.pid == saved.pid,
                state.pocketSlot(of: id) == nil,
                isEffectiveFloatForPlacement(id)
            else { continue }
            tiler.forgetSizeBound(id)
            if placementIsSeed(id) {
                tiler.seedStash(id, frame: saved.frame)
                continue
            }
            tiler.applyFrame(
                id,
                from: tiler.commandedFrame(of: id) ?? window.frame,
                to: saved.frame,
                animated: tiler.settings.animations.onStateChange,
                sizing: .allSpringSized
            )
            holdRingForStateChange([id])
        }
    }

    /// Ends `id`'s Maximize ahead of a float verb that acts on its
    /// frame — `move_floating`, `center_floating`, a float resize —
    /// and puts it back first, so the verb acts from the frame it
    /// returns to.
    func endMaximizeBeforeFloatVerb(_ id: WindowID) {
        guard endMaximize(of: id) else { return }
        payMaximizedFloatReturns()
    }

    /// A drop that ends a float's Maximize (#3036): an edge resize
    /// keeps the new size and forgets the return frame, any other
    /// gesture puts the window back without acting on the drop.
    /// Returns whether the drop is spent.
    func settleMaximizedFloatDrop(
        _ id: WindowID,
        start: CGRect,
        frame: CGRect
    ) -> Bool {
        guard state.maximizedFloatReturn[id] != nil else { return false }
        if MouseResize.isResize(from: start, to: frame) {
            state.maximizedFloatReturn[id] = nil
            return false
        }
        payMaximizedFloatReturns()
        return true
    }
}
