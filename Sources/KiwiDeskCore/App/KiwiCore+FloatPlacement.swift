import CoreGraphics

/// The float placement: a window an explicit float verb floats
/// is centred at the derived `FloatPlacement` size, since the
/// frame it leaves was the layout's slot and never the user's
/// (`docs/design-decisions.md` ▸ the float placement entry).
extension KiwiCore {
    /// Places a just-floated `id` per `float_placement`. Callers
    /// gate the transition (a window that was not already an
    /// effective float); the setting gate lives here. Reads the
    /// cached state frame, never AX, and rides the relayout
    /// animation so the move reads as deliberate.
    func placeFloating(_ id: WindowID) {
        guard tiler.settings.floatPlacement == .center,
            let current = state.windows[id]?.frame,
            // The grow bound: a placement nothing will correct
            // lays its frame clear of the ring too (#1091).
            let region = floatGrowBounds(of: id)
        else { return }
        let bound = tiler.sizeBound(for: id)
        let target = FloatPlacement.centered(
            in: region,
            minimum: CGSize(
                width: bound?.minWidth ?? 0,
                height: bound?.minHeight ?? 0
            )
        )
        tiler.applyFrame(
            id,
            from: current,
            to: target,
            animated: tiler.settings.animations.onRelayout
        )
    }
}
