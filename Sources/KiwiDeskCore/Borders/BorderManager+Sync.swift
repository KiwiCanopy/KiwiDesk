import AppKit

/// BorderManager ring overlay synchronization and rendering paths
/// (`FollowSource`, #594, #596).
extension BorderManager {
    /// Synchronizes overlays to match desired specs and retires unused
    /// overlays (`FollowSource.syncFrame`, #596).
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
                glowBlur: spec.glowBlur
            )
            overlay.order(relativeTo: spec.window.raw)
        }
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
            restoreVisibility: restoreVisibility
        )
    }
}
