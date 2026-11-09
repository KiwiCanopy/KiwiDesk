import CoreGraphics

/// A maximized float's way back (#3036). An ender only clears the
/// flag; the frame is paid here, at the tail of `retile()` or by a
/// verb that ends the Maximize before it acts, so no ender owes a
/// write of its own.
extension KiwiCore {
    /// Puts every float whose Maximize ended back at its return
    /// frame — seeded as its pending capture where its Space is not
    /// shown — and drops the record; `only` pays that window alone.
    /// A window the hand holds, or one in native full screen, keeps
    /// it for a later pass; one that tiled, entered the pocket or is
    /// gone takes none. Returns the frames it wrote or seeded.
    @discardableResult
    func payMaximizedFloatReturns(
        only: WindowID? = nil
    ) -> [WindowID: CGRect] {
        var paid: [WindowID: CGRect] = [:]
        for (id, saved) in state.owedMaximizedFloatReturns()
        where only == nil || only == id {
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
            let target = returnFrame(saved.frame, of: id)
            paid[id] = target
            if placementIsSeed(id) {
                tiler.seedStash(id, frame: target)
                continue
            }
            tiler.applyFrame(
                id,
                from: tiler.commandedFrame(of: id) ?? window.frame,
                to: target,
                animated: tiler.settings.animations.onStateChange,
                sizing: .allSpringSized
            )
            holdRingForStateChange([id])
        }
        return paid
    }

    /// `frame` confined to the float region of the Space `id` is
    /// drawn on, as a remembered float frame is (#1675), and centred
    /// there first where it lies on another screen: the window or
    /// its Space moved screens while it filled one.
    private func returnFrame(_ frame: CGRect, of id: WindowID) -> CGRect {
        guard let space = floatPlacementSpace(of: id),
            let region = floatGrowBounds(on: space)
        else { return frame }
        let sameScreen = FloatPlacement.onSameScreen(
            frame,
            as: region,
            among: tiler.allScreenBounds()
        )
        return FloatPlacement.restored(
            sameScreen
                ? frame : FloatRecovery.centred(frame.size, in: region),
            in: region
        )
    }

    /// Ends `id`'s Maximize ahead of a float verb that acts on its
    /// frame — `move_floating`, `center_floating`, a float resize —
    /// and puts it back first; a return a held pass still owes is
    /// paid the same. Returns the frame it put the window back at,
    /// the verb's base, since no echo has reported it yet.
    @discardableResult
    func endMaximizeBeforeFloatVerb(_ id: WindowID) -> CGRect? {
        endMaximize(of: id)
        return payMaximizedFloatReturns(only: id)[id]
    }

    /// A drop of a float whose Maximize ended, by this gesture or a
    /// pass still owing its return (#3036): an edge resize keeps the
    /// new size and forgets the return frame, any other gesture puts
    /// the window back without acting on the drop. Returns whether
    /// the drop is spent.
    func settleMaximizedFloatDrop(
        _ id: WindowID,
        start: CGRect,
        frame: CGRect
    ) -> Bool {
        guard state.owedMaximizedFloatReturns()[id] != nil else {
            return false
        }
        if MouseResize.isResize(from: start, to: frame) {
            state.maximizedFloatReturn[id] = nil
            return false
        }
        payMaximizedFloatReturns(only: id)
        return true
    }
}
