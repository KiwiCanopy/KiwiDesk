import CoreGraphics

/// The float placement: a window an explicit float verb floats,
/// or a move verb files into a floating Space (#1708), is centred
/// at the derived `FloatPlacement` size, since the frame it
/// leaves was the layout's slot and never the user's
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
    /// read before the flip; the setting gate lives here. On a
    /// Space no screen shows — a verb naming its window (#1518) —
    /// the frame is seeded as its pending capture, paid at the
    /// activation, as `placeEnteringFloat` does.
    func placeFloating(_ id: WindowID) {
        guard let window = state.windows[id] else { return }
        if let space = floatPlacementSpace(of: id),
            !state.workspaces.visibleSpaces.contains(space)
        {
            if seedsPlacement(id),
                let target = floatPlacementTarget(for: id)
            {
                seedPlacement(id, target)
            }
            return
        }
        guard let target = floatPlacementTarget(for: id) else { return }
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

    /// What a detection flip owes (#1820), read before the fold:
    /// a window that was no effective float and now floats is
    /// placed as the float verbs place one, and an effective
    /// float detection tiles files its frame as `make_tiled`
    /// does (#1675), so a rule coming back returns it there.
    enum DetectedFlip {
        case floats(WindowID)
        case tiles(WindowID, StateCoordinator.FloatFrame?)
    }

    func detectedFlip(_ event: KiwiEvent) -> DetectedFlip? {
        guard case .windowFloatChanged(let id, let floating) = event,
            state.windows[id] != nil
        else { return nil }
        let wasFloat = isEffectiveFloatForPlacement(id)
        if floating { return wasFloat ? nil : .floats(id) }
        return wasFloat ? .tiles(id, floatFrameToRemember(id)) : nil
    }

    /// Pays `detectedFlip`'s debt once the fold has run: a float
    /// flip always lands, a tile one only where the fold really
    /// tiled the window. The placement stands down while event
    /// retiles are deferred (boot, a sweep chunk: the frame is the
    /// app's, not a slot) and for a window a drag holds or in its
    /// own macOS Space (#670).
    func settleDetectedFlip(_ flip: DetectedFlip?) {
        switch flip {
        case .floats(let id):
            guard !defersEventRetiles, seedsPlacement(id)
            else { return }
            placeFloating(id)
        case .tiles(let id, let frame):
            guard let frame, !isEffectiveFloatForPlacement(id)
            else { return }
            state.floatFrames[id] = frame
        case nil:
            break
        }
    }

    /// Places a window a move verb just filed into a floating
    /// Space where it was no effective float before (#1708):
    /// the frame it brings is the layout's slot, as at the float
    /// verbs. Seeded as its pending capture, so the restore
    /// delivers it — at once where the Space shows, at the
    /// activation where it is parked. Returns whether it placed;
    /// a sticky and a dragged window keep the re-anchor.
    func placeEnteringFloat(_ id: WindowID, wasFloat: Bool) -> Bool {
        guard !wasFloat,
            state.windows[id]?.isSticky == false,
            seedsPlacement(id),
            isEffectiveFloatForPlacement(id),
            let target = floatPlacementTarget(for: id)
        else { return false }
        seedPlacement(id, target)
        return true
    }

    /// Whether `id` may take its placement as a pending capture —
    /// asked before the target is read, which consumes the
    /// remembered frame. Never a window in its own macOS Space
    /// (#670): nothing parks it, so a seed would be re-delivered
    /// every retile; never one a drag holds.
    private func seedsPlacement(_ id: WindowID) -> Bool {
        guard let window = state.windows[id] else { return false }
        return !window.isFullscreen && tiler.dragExemptWindow != id
    }

    /// The one seeding of a placement, delivered by the restore.
    private func seedPlacement(_ id: WindowID, _ target: CGRect) {
        tiler.seedStash(id, frame: target)
        tiler.forgetSizeBound(id)
    }

    /// Where `id` floats on its placement space: its remembered
    /// frame, else centred at the derived size and cascaded off
    /// the other floats there (#1708); nil under `keep`.
    private func floatPlacementTarget(for id: WindowID) -> CGRect? {
        guard tiler.settings.floatPlacement == .center,
            state.windows[id] != nil,
            let space = floatPlacementSpace(of: id),
            // The grow bound: a placement nothing will correct
            // lays its frame clear of the ring too (#1091).
            let region = floatGrowBounds(on: space)
        else { return nil }
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
        if let remembered { return remembered }
        let centred = FloatPlacement.centered(
            in: region,
            minimum: minimum,
            maximum: CGSize(
                width: bound?.maxWidth ?? .infinity,
                height: bound?.maxHeight ?? .infinity
            )
        )
        return FloatPlacement.cascaded(
            centred,
            avoiding: otherFloatFrames(on: space, besides: id),
            in: region
        )
    }

    /// The frames the other effective floats on `space` show or
    /// will show, a parked one's pending capture first: its own
    /// members, the travelers it draws now, and every ∞ window,
    /// which an unshown Space draws once it activates.
    private func otherFloatFrames(
        on space: SpaceID,
        besides id: WindowID
    ) -> [CGRect] {
        guard let workspace = state.workspaces[space] else { return [] }
        let global = state.windows.all
            .filter { $0.stickyScope == .global }.map(\.id)
        var seen = Set<WindowID>()
        let candidates =
            (workspace.windows
            + state.effectiveMembers(of: workspace) + global)
            .filter { seen.insert($0).inserted }
        return candidates.compactMap { other in
            guard other != id,
                let window = state.windows[other],
                !window.isFullscreen,
                EffectiveFloat.applies(
                    isFloating: window.isFloating,
                    mode: workspace.mode
                )
            else { return nil }
            return wouldBeFrame(of: window)
        }
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
    /// retile just before may have issued a move already. No
    /// stash rung, unlike `wouldBeFrame`: this is where the window
    /// SITS, the base an animation starts from.
    private func currentFrame(
        of id: WindowID,
        fallback: CGRect
    ) -> CGRect {
        tiler.commandedFrame(of: id) ?? fallback
    }
}
