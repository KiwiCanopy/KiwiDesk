import Foundation

extension KiwiCore {
    /// The plane the float layer is lifted over on `space`: its
    /// tiled members that are not EFFECTIVE floats (#1286). A
    /// floating-mode space places nothing, so it has no plane and
    /// the switch-time raise lifts nothing over its members — the
    /// per-focus arm (`raiseFloatsAbove`) stands down the same way.
    /// The sequence still runs over the flag and sticky targets,
    /// and with no floor its one remaining assertion is #418's id
    /// order among them (`raiseFloor`'s "floats keep their order
    /// among themselves"): a lower-id float put in front of a
    /// higher-id one is re-stacked on a switch, as on every space.
    func floatRaiseFloor(
        of space: Space,
        excluding focused: WindowID?
    ) -> [WindowID] {
        Self.raiseFloor(
            tiled: state.effectiveTiledMembers(of: space).filter {
                !EffectiveFloat.applies(
                    isFloating: state.windows[$0]?.isFloating == true,
                    mode: space.mode
                )
            },
            excluding: focused
        )
    }

    /// The ids of the windows that belong ABOVE the tiled plane:
    /// the active space's floating windows plus every floating
    /// sticky window (visible on all spaces, never stashed). The
    /// gate is `isFloating`, never `isSticky` alone — a tiled-sticky
    /// window is a real layout participant (#414 v2) and stays on
    /// the tiled plane. Sorted by id so overlapping floats keep a
    /// stable order across passes.
    ///
    /// **Known residue, mixed CGWindow layers (#684).** A float
    /// may sit at layer 0 (a normal window the user floated) or
    /// above it (`FloatDetection` floats a panel *because* its
    /// layer is non-zero). The compositor keeps a raised-layer
    /// window above every layer-0 one no matter what is raised, so
    /// whenever this array order asks for a layer-0 float in FRONT
    /// of a raised-layer one, that pairing cannot be reached: the
    /// sequence issues one raise that cannot verify and spends
    /// `ZOrderDrain.landingLimit` finding out. Bounded, once per
    /// float raise, and only in that mixed configuration — and the
    /// stacking is still correct, because the raised-layer float
    /// is above where the user needs it either way.
    ///
    /// Fixing it properly means ordering the desired sequence by
    /// layer, which needs the layer at this call site: it is NOT
    /// `isTransientOverlay` (that flag also covers layer-0
    /// dialogs, #300/#671), so it costs either a per-window
    /// WindowServer query here or a layer-carrying stacking read
    /// threaded into the drain. Deferred rather than guessed.
    func floatLayerTargets() -> [WindowID] {
        var targets: [WindowID] = []
        if let space = activeSpace {
            targets = space.windows.filter {
                state.windows[$0]?.isFloating == true
            }
        }
        for window in state.windows.all
            .sorted(by: { $0.id.raw < $1.id.raw })
        where window.isSticky && window.isFloating
            && !targets.contains(window.id)
        {
            targets.append(window.id)
        }
        return targets
    }
}
