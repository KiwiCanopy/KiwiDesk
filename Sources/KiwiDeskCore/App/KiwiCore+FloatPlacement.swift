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
        let minimum = CGSize(
            width: bound?.minWidth ?? 0,
            height: bound?.minHeight ?? 0
        )
        // The frame it floated at last, where it still lies on this
        // Space's screen (#1675); consumed either way.
        let remembered = state.floatFrames.removeValue(forKey: id)
            .flatMap { saved -> CGRect? in
                guard
                    FloatPlacement.onSameScreen(
                        saved.frame,
                        as: region,
                        among: tiler.allScreenBounds()
                    )
                else { return nil }
                return FloatPlacement.restored(
                    saved.frame,
                    in: region,
                    minimum: minimum
                )
            }
        let target =
            remembered
            ?? FloatPlacement.centered(
                in: region,
                minimum: minimum,
                maximum: CGSize(
                    width: bound?.maxWidth ?? .infinity,
                    height: bound?.maxHeight ?? .infinity
                )
            )
        let base = currentFrame(of: id, fallback: window.frame)
        tiler.applyFrame(
            id,
            from: base,
            to: target,
            animated: tiler.settings.animations.onRelayout
        )
        // A size change outside the layout's asks (#677): its echo
        // must not read as the app refusing the last tiled ask, or
        // the next tiled space places the float's size as residue.
        tiler.forgetSizeBound(id)
    }

    /// Where a float sits as it is about to be tiled (#1675), for
    /// `placeFloating` to return it there — never a parked frame,
    /// since a corner is never a float's original (#1352).
    func floatFrameToRemember(
        _ id: WindowID
    ) -> StateCoordinator.FloatFrame? {
        guard let window = state.windows[id] else { return nil }
        let frame = currentFrame(of: id, fallback: window.frame)
        guard !tiler.looksStashed(frame) else { return nil }
        return .init(pid: window.pid, frame: frame)
    }

    /// The commanded frame outranks the echo-fed state one: a
    /// retile just before may have issued a move already.
    private func currentFrame(
        of id: WindowID,
        fallback: CGRect
    ) -> CGRect {
        tiler.animation.commandedFrame(
            window: id,
            includingHeldGlide: false
        )
            ?? tiler.recentInstantTarget(id)
            ?? fallback
    }
}
