import AppKit

extension BorderManager {
    /// Rubber-bands focus ring toward boundary for dead-end cue (#436).
    func flashDeadEnd(
        window: WindowID,
        frame: CGRect,
        direction: Direction,
        colorHex: String,
        width: CGFloat,
        cornerStyle: BorderStyle.CornerStyle,
        reduceMotion: Bool
    ) {
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
    /// Returns whether a pill was actually DRAWN (#1255): the
    /// refusal's sound follows the drawing, so a caller cannot
    /// tell "I asked" from "it appeared" without this.
    @discardableResult
    func flashSizeLimitPill(
        window: WindowID,
        frame: CGRect,
        text: String
    ) -> Bool {
        guard privateRuntimeStarted else { return false }
        sizeLimitOverlay.flash(
            window: window.raw,
            frame: frame,
            text: text
        )
        return true
    }
}
