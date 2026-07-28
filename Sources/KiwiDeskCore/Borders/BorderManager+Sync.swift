import AppKit

/// The frame paths of `BorderManager` — everything that decides
/// WHERE a ring is drawn and who is allowed to move it. Split out
/// of `BorderManager.swift` to keep each file under the size
/// ceiling; the main type keeps the store, the lifecycle and the
/// per-window caches those paths read.
///
/// Three entry points, in descending order of authority while our
/// own animation drives a window (#594/#596): `apply` is
/// unguarded and belongs to whoever owns the frame outright (the
/// WindowServer re-read); `follow` carries a `FollowSource` and
/// asks the shared decision; `sync` is the steady-state rebuild
/// and stands down on geometry alone.
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
            overlay.update(
                frame: syncFrame(for: spec, overlay: overlay),
                width: spec.width,
                cornerStyle: spec.cornerStyle,
                cornerRadius: cornerRadius(for: spec.window),
                colorHex: spec.colorHex,
                screen: screen(for: spec.frame),
                glowBlur: spec.glowBlur
            )
            // Re-assert stacking each sync (focus change, retile,
            // z-order restore) — the target may have moved in the
            // window order since the ring last positioned.
            overlay.order(relativeTo: spec.window.raw)
        }
    }

    /// The frame a steady-state `sync` renders a ring at. Normally
    /// the spec's; while OUR OWN animation drives the window the
    /// ring holds where the last tick put it instead, because the
    /// spec carries the echo-fed frame the motion has already left
    /// behind (`FollowSource.steadySync`, #596). Everything else
    /// `sync` does — create, recolor, re-order, retire — is
    /// unaffected: only the geometry stands down.
    ///
    /// A ring being CREATED mid-flight (a focus change during a
    /// pan) has no held frame and takes the spec's, one tick
    /// behind; there is nothing better to show it, and the next
    /// tick corrects it.
    private func syncFrame(
        for spec: Spec,
        overlay: BorderOverlay
    ) -> CGRect {
        if FollowSource.steadySync.applies(
            wsTracked: usesWindowServerTracking(spec.window),
            animating: isAnimating(spec.window)
        ) {
            return spec.frame
        }
        return overlay.lastRenderedFrame ?? spec.frame
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

    /// Unguarded reposition — the WS bounds re-read (`reconcile`)
    /// and the steady-state `sync` own the ring's frame directly,
    /// so they bypass the guards on `follow`. Internal, not
    /// private: `reconcile` lives in the `+SkyLight` extension.
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
