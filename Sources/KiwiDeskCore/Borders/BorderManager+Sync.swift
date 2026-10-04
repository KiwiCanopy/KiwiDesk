import AppKit

/// BorderManager ring overlay synchronization and rendering
/// paths. Three writers, descending authority while our own
/// animation drives a window (#594/#596): `apply` is unguarded
/// (the WS re-read owns the frame), `follow` asks
/// `FollowSource`, `sync` rebuilds everything but holds an
/// animating window's geometry.
extension BorderManager {
    #if DEBUG
        /// Test-only: a full re-stack that prunes nothing.
        func sync(_ desired: [Spec]) {
            sync(desired, alive: nil, reassertOrder: true)
        }
    #endif

    /// Synchronizes overlays to match desired specs and retires unused
    /// overlays (`FollowSource.syncFrame`, #596).
    /// `alive` prunes dormant rings of windows outside it (nil
    /// keeps them all). `reassertOrder` re-stacks every ring; off,
    /// only a ring that needs ordering in is ordered (#1925).
    public func sync(
        _ desired: [Spec],
        alive: Set<WindowID>?,
        reassertOrder: Bool
    ) {
        let wanted = Set(desired.map(\.window))
        #if DEBUG
            lastSyncReassertedOrder = reassertOrder
        #endif
        for (id, overlay) in overlays where !wanted.contains(id) {
            overlay.retire()
            dormant[id] = overlay
            overlays[id] = nil
            specs[id] = nil
        }
        if let alive {
            for (id, overlay) in dormant where !alive.contains(id) {
                overlay.hide()
                dormant[id] = nil
                cornerRadii[id] = nil
            }
        }
        // Before the loop, so the order policy reads this sync's
        // tracking verdict; the set equals the one after it.
        updateSkyLightSubscription(wanted)
        for spec in desired {
            specs[spec.window] = spec
            let overlay = overlay(for: spec.window)
            // Only geometry stands down mid-animation (#596);
            // create, recolor and retire run unconditionally.
            // `screen` MUST derive from this same
            // rect, not `spec.frame`: it picks the backing scale,
            // and a held frame paired with the spec's screen
            // rasterizes the ring at the wrong display's scale.
            let frame = FollowSource.syncFrame(
                spec: spec.frame,
                held: overlay.lastRenderedFrame,
                animating: isAnimating(spec.window),
                commanded: commandedFrame(spec.window)
            )
            overlay.update(
                frame: frame,
                width: spec.width,
                cornerStyle: spec.cornerStyle,
                cornerRadius: cornerRadius(for: spec.window),
                colorHex: spec.colorHex,
                screen: screen(for: frame),
                glowBlur: spec.glowBlur,
                sheen: spec.sheen
            )
            // Without the WindowServer stream no reorder event
            // tells a shown ring its target moved, so every sync
            // re-stacks.
            if Self.ordersRing(
                reassert: reassertOrder,
                needsOrder: overlay.needsOrder,
                tracked: skyLightActive
            ) {
                overlay.order(relativeTo: spec.window.raw)
            }
        }
    }

    /// Whether `sync` orders a ring: a settle pass re-stacks all,
    /// a steady one only a ring not yet shown, unless no
    /// WindowServer stream reports its target moving (#1925).
    static func ordersRing(
        reassert: Bool,
        needsOrder: Bool,
        tracked: Bool
    ) -> Bool {
        reassert || needsOrder || !tracked
    }

    /// Moves overlay to match window frame during animation or AX echo
    /// (`FollowSource.renderFrame`, #285, #594, #677).
    public func follow(
        _ id: WindowID,
        windowFrame: CGRect,
        source: FollowSource,
        pin: SizePin?
    ) {
        guard
            let frame = source.renderFrame(
                reported: windowFrame,
                pin: pin,
                wsTracked: usesWindowServerTracking(id),
                animating: isAnimating(id)
            )
        else { return }
        apply(id, windowFrame: frame)
    }

    /// Returns last rendered frame for testing (#596).
    func lastFrame(_ id: WindowID) -> CGRect? {
        overlays[id]?.lastRenderedFrame
    }

    /// Returns last rendered color hex for testing (#596).
    func lastColorHex(_ id: WindowID) -> String? {
        overlays[id]?.lastRenderedColorHex
    }

    /// Repositions overlay without follow guards
    /// (`FollowSource.syncFrame`, #596).
    func apply(
        _ id: WindowID,
        windowFrame: CGRect,
        restoreVisibility: Bool = false
    ) {
        guard let overlay = overlays[id], let spec = specs[id]
        else { return }
        let screen = screen(for: windowFrame)
        overlay.update(
            frame: windowFrame,
            width: spec.width,
            cornerStyle: spec.cornerStyle,
            cornerRadius: cornerRadius(for: id),
            colorHex: spec.colorHex,
            screen: screen,
            glowBlur: spec.glowBlur,
            sheen: spec.sheen,
            restoreVisibility: restoreVisibility,
            // An animating ring moves inside a screen-sized panel
            // rather than resizing it per frame, which waits on
            // WindowServer (#1937); the settle resizes it back.
            room: isAnimating(id) ? screen?.frame : nil
        )
    }
}
