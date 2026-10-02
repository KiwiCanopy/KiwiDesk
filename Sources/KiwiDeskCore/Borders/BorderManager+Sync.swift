import AppKit

/// BorderManager ring overlay synchronization and rendering
/// paths. Three writers, descending authority while our own
/// animation drives a window (#594/#596): `apply` is unguarded
/// (the WS re-read owns the frame), `follow` asks
/// `FollowSource`, `sync` rebuilds everything but holds an
/// animating window's geometry.
extension BorderManager {
    /// Synchronizes overlays to match desired specs and retires unused
    /// overlays (`FollowSource.syncFrame`, #596).
    /// `alive`, when given, prunes dormant rings of windows no
    /// longer tracked. `reassertOrder` re-stacks every ring; off,
    /// only a ring that needs ordering in is ordered (#1925).
    public func sync(
        _ desired: [Spec],
        alive: Set<WindowID>? = nil,
        reassertOrder: Bool = true
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
        // After the ring set settles: a dormant ring stays watched,
        // so a Space switch leaves the request unchanged (#1925).
        updateSkyLightSubscription(wanted)
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
        overlay.update(
            frame: windowFrame,
            width: spec.width,
            cornerStyle: spec.cornerStyle,
            cornerRadius: cornerRadius(for: id),
            colorHex: spec.colorHex,
            screen: screen(for: windowFrame),
            glowBlur: spec.glowBlur,
            sheen: spec.sheen,
            restoreVisibility: restoreVisibility
        )
    }
}
