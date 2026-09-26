import CoreGraphics

/// The float placement: a window an explicit float verb floats
/// is centred at the derived `FloatPlacement` size, since the
/// frame it leaves was the layout's slot and never the user's
/// (`docs/design-decisions.md` ▸ the float placement entry).
extension KiwiCore {
    /// The space the placement plays out on: the one a sticky
    /// traveler RENDERS on, else the window's own (#1217) — the
    /// same space for the gate and the region.
    func floatPlacementSpace(of id: WindowID) -> SpaceID? {
        guard let window = state.windows[id] else { return nil }
        return state.stickyRenderSpace(of: window)
            ?? state.workspaces.space(of: id)
    }

    /// Whether `id` is already an effective float where it would
    /// be placed — the verb's gate, ruled onto `EffectiveFloat`.
    func isEffectiveFloatForPlacement(_ id: WindowID) -> Bool {
        EffectiveFloat.applies(
            isFloating: state.windows[id]?.isFloating == true,
            mode: floatPlacementSpace(of: id).flatMap {
                state.workspaces[$0]?.mode
            }
        )
    }

    /// Places a just-floated `id` per `float_placement`. Callers
    /// gate the transition on `isEffectiveFloatForPlacement`
    /// read before the flip; the setting gate lives here.
    func placeFloating(_ id: WindowID) {
        guard tiler.settings.floatPlacement == .center,
            let window = state.windows[id],
            let space = floatPlacementSpace(of: id),
            // The grow bound: a placement nothing will correct
            // lays its frame clear of the ring too (#1091).
            let region = floatGrowBounds(on: space)
        else { return }
        let bound = tiler.sizeBound(for: id)
        let target = FloatPlacement.centered(
            in: region,
            minimum: CGSize(
                width: bound?.minWidth ?? 0,
                height: bound?.minHeight ?? 0
            ),
            maximum: CGSize(
                width: bound?.maxWidth ?? .infinity,
                height: bound?.maxHeight ?? .infinity
            )
        )
        // The commanded frame outranks the echo-fed state one:
        // the retile just before may have issued a move already.
        let base =
            tiler.animation.commandedFrame(
                window: id,
                includingHeldGlide: false
            )
            ?? tiler.recentInstantTarget(id)
            ?? window.frame
        tiler.applyFrame(
            id,
            from: base,
            to: target,
            animated: tiler.settings.animations.onRelayout
        )
    }
}
