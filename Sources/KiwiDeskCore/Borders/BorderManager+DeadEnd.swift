import AppKit

extension BorderManager {
    /// Rubber-bands `window`'s focus ring toward the wall for the
    /// dead-end cue (#436). The ring itself never moves the window —
    /// only the overlay geometry animates (`BorderOverlay.renderBump`).
    ///
    /// Works whether or not borders are enabled: a live steady-state
    /// ring is bumped in place, and a window with no ring gets a
    /// **transient** overlay kept in `bumpTransients` (never in the
    /// `overlays` store `sync` owns), bumped, then torn down on
    /// settle — so the two lifecycles can never adopt or stomp each
    /// other.
    func flashDeadEnd(
        window: WindowID,
        frame: CGRect,
        direction: Direction,
        colorHex: String,
        width: CGFloat,
        cornerStyle: BorderStyle.CornerStyle,
        reduceMotion: Bool
    ) {
        // Inert until the app lifecycle has started, mirroring the
        // SkyLight-runtime dormancy (`start()`): keeps unit tests and
        // previews from spawning panels + display links on the many
        // command dead-ends they exercise.
        guard privateRuntimeStarted, let screen = screen(for: frame)
        else { return }

        let overlay: BorderOverlay
        if let live = overlays[window] {
            overlay = live
        } else {
            // Borders off for this window: spawn (or reuse) a
            // transient ring outside `overlays` and establish it so
            // the bump has something to shift.
            let ring = bumpTransients[window] ?? makeOverlay(for: window)
            bumpTransients[window] = ring
            ring.update(
                frame: frame,
                width: width,
                cornerStyle: cornerStyle,
                cornerRadius: cornerRadius(for: window),
                colorHex: colorHex,
                screen: screen,
                // Explicitly bloom-less, not an omitted default:
                // the transient is a directional cue borrowing
                // the ring's look, never the focus ring (glow is
                // focused-only, #358), and blooming it would
                // spawn an AppKit backend for a ~200 ms flash.
                glowBlur: 0
            )
            ring.order(relativeTo: window.raw)
            overlay = ring
        }

        bumpAnimator.flash(
            window: window,
            overlay: overlay,
            impulse: DeadEndBump.impulse(for: direction),
            colorHex: colorHex,
            screen: screen,
            reduceMotion: reduceMotion
        ) { [weak self] in
            guard let self else { return }
            // Retire only a transient we spawned; a live ring is left
            // to the steady-state sync (no-op if none is stored).
            self.bumpTransients[window]?.hide()
            self.bumpTransients[window] = nil
            // Drop the radius we cached only for this transient —
            // unless a steady ring adopted the window meanwhile.
            if self.overlays[window] == nil {
                self.forgetCornerRadius(window)
            }
        }
    }
}
