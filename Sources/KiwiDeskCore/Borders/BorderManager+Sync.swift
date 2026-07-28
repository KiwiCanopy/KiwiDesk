import AppKit

/// `BorderManager`'s ring-rendering paths: the steady-state
/// `sync` (which also creates and retires overlays), the
/// animation / AX-echo `follow`, the unguarded `apply`, and the
/// test seams that read back what was rendered. Split out when
/// #596's additions pushed `BorderManager.swift` past the 350
/// line ceiling; the main type keeps the stores, the app
/// lifecycle, the draw-order flip and the per-window caches
/// these read.
///
/// The three writers, in descending order of authority while our
/// own animation drives a window (#594/#596): `apply` is
/// unguarded and belongs to whoever owns the frame outright (the
/// WindowServer re-read); `follow` carries a `FollowSource` and
/// asks the shared decision; `sync` rebuilds everything but
/// holds an animating window's geometry.
extension BorderManager {
    /// Shows exactly `desired` — one ring per window — and retires
    /// the overlays of any window no longer in the set (an empty
    /// array retires them all).
    public func sync(_ desired: [Spec]) {
        let wanted = Set(desired.map(\.window))
        updateSkyLightSubscription(wanted)
        for (id, overlay) in overlays where !wanted.contains(id) {
            overlay.hide()
            overlays[id] = nil
            specs[id] = nil
            cornerRadii[id] = nil
        }
        for spec in desired {
            specs[spec.window] = spec
            let overlay = overlay(for: spec.window)
            // Geometry stands down mid-animation (#596) — the one
            // decision the mark's `sync` shares. Everything else
            // here (create, recolor, re-order, retire) runs
            // unconditionally: only the frame is held back.
            // `screen` MUST derive from the same rect, not from
            // `spec.frame`: it selects the backing scale, so on a
            // cross-display animated move a held frame paired with
            // the spec's screen rasterizes the ring at the wrong
            // display's scale.
            let frame = FollowSource.syncFrame(
                spec: spec.frame,
                held: overlay.lastRenderedFrame,
                animating: isAnimating(spec.window)
            )
            overlay.update(
                frame: frame,
                width: spec.width,
                cornerStyle: spec.cornerStyle,
                cornerRadius: cornerRadius(for: spec.window),
                colorHex: spec.colorHex,
                screen: screen(for: frame),
                glowBlur: spec.glowBlur
            )
            // Re-assert stacking each sync (focus change, retile,
            // z-order restore) — the target may have moved in the
            // window order since the ring last positioned.
            overlay.order(relativeTo: spec.window.raw)
        }
    }

    /// Animation / AX-echo hot path: move an already-shown ring
    /// to a window's current frame. The stand-down decision is
    /// `FollowSource.applies` — one switch shared with the
    /// sticky mark, so no caller re-implements it (#285) and the
    /// two overlays cannot drift (#594). A no-op for windows
    /// without a ring.
    public func follow(
        _ id: WindowID,
        windowFrame: CGRect,
        source: FollowSource
    ) {
        guard
            source.applies(
                wsTracked: usesWindowServerTracking(id),
                animating: isAnimating(id)
            )
        else { return }
        apply(id, windowFrame: windowFrame)
    }

    /// The frame a window's ring last rendered against, for
    /// tests that need to prove `follow` stood down (or didn't).
    func lastFrame(_ id: WindowID) -> CGRect? {
        overlays[id]?.lastRenderedFrame
    }

    /// Its colour sibling — for proving a `sync` that stood down
    /// on geometry still recolored (#596).
    func lastColorHex(_ id: WindowID) -> String? {
        overlays[id]?.lastRenderedColorHex
    }

    /// Unguarded reposition — the WS bounds re-read
    /// (`reconcile`) owns the ring's frame outright, so it
    /// bypasses the guards on `follow`. Internal, not private:
    /// `reconcile` lives in the `+SkyLight` extension. `sync`
    /// does NOT come through here; it asks
    /// `FollowSource.syncFrame` first (#596).
    func apply(
        _ id: WindowID,
        windowFrame: CGRect,
        restoreVisibility: Bool = false
    ) {
        guard let overlay = overlays[id], let spec = specs[id]
        else { return }
        overlay.update(
            frame: windowFrame,
            width: spec.width,
            cornerStyle: spec.cornerStyle,
            cornerRadius: cornerRadius(for: id),
            colorHex: spec.colorHex,
            screen: screen(for: windowFrame),
            glowBlur: spec.glowBlur,
            restoreVisibility: restoreVisibility
        )
    }
}
