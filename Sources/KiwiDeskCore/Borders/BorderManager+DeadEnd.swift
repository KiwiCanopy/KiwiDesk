import AppKit

extension BorderManager {
    /// Rubber-bands focus ring toward the boundary (#436). A
    /// window with no ring gets a TRANSIENT overlay kept in
    /// `bumpTransients` — never in the `overlays` store `sync`
    /// owns — so the two lifecycles can never adopt or stomp each
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
        // Inert until the app lifecycle has started: keeps unit
        // tests and previews from spawning panels + display links
        // on the many command dead-ends they exercise.
        guard privateRuntimeStarted, let screen = screen(for: frame)
        else { return }

        let overlay: BorderOverlay
        if let live = overlays[window] {
            overlay = live
        } else {
            // Spawn transient ring in bumpTransients without glow (#358).
            let ring = bumpTransients[window] ?? makeOverlay(for: window)
            bumpTransients[window] = ring
            ring.update(
                frame: frame,
                width: width,
                cornerStyle: cornerStyle,
                cornerRadius: cornerRadius(for: window),
                colorHex: colorHex,
                screen: screen,
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
            self.bumpTransients[window]?.hide()
            self.bumpTransients[window] = nil
            if self.overlays[window] == nil {
                self.forgetCornerRadius(window)
            }
        }
    }

    /// Flashes the minimum-size refusal pill on `window` (#933).
    func flashSizeLimitPill(
        window: WindowID,
        frame: CGRect,
        text: String
    ) {
        guard privateRuntimeStarted else { return }
        sizeLimitOverlay.flash(
            window: window.raw,
            frame: frame,
            text: text
        )
    }
}
