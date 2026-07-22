import AppKit

extension BorderManager {
    /// Rubber-bands `window`'s focus ring toward the wall for the
    /// dead-end cue (#436). The ring itself never moves the window —
    /// only the overlay geometry animates (`BorderOverlay.renderBump`).
    ///
    /// Works whether or not borders are enabled: if the window has no
    /// live ring, a transient overlay is spawned from the passed
    /// style, bumped, then torn down on settle — so borders-off users
    /// get the same cue. When a ring already exists it is bumped in
    /// place and left standing.
    func flashDeadEnd(
        window: WindowID,
        frame: CGRect,
        direction: Direction,
        colorHex: String,
        width: CGFloat,
        cornerStyle: BorderStyle.CornerStyle,
        reduceMotion: Bool
    ) {
        guard let screen = screen(for: frame) else { return }
        let hadRing = overlays[window] != nil
        let overlay = overlay(for: window)
        if !hadRing {
            // Establish the ring so the bump has something to shift,
            // then order it into the target's band for the flash.
            overlay.update(
                frame: frame,
                width: width,
                cornerStyle: cornerStyle,
                cornerRadius: cornerRadius(for: window),
                colorHex: colorHex,
                screen: screen
            )
            overlay.order(relativeTo: window.raw)
        }
        bumpAnimator.flash(
            window: window,
            overlay: overlay,
            impulse: DeadEndBump.impulse(for: direction),
            colorHex: colorHex,
            screen: screen,
            reduceMotion: reduceMotion
        ) { [weak self] in
            // Tear down only what this cue spawned; a pre-existing
            // ring stays under the steady-state sync's ownership.
            guard let self, !hadRing else { return }
            self.overlays[window]?.hide()
            self.overlays[window] = nil
            self.cornerRadii[window] = nil
        }
    }
}
