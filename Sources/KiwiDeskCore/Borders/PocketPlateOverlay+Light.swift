import AppKit

/// The pocket's light (#2776): a window going in or out lights it a
/// moment, shown full, and the empty pocket at rest fades. The view's
/// `PocketPlateView.flashing` is the one flag.
extension PocketPlateOverlay {
    /// How long a window going in, and one coming out, lights the
    /// pocket.
    static let inHold: TimeInterval = 0.5
    static let outHold: TimeInterval = 0.4

    /// Lights `shown` for `hold`, then lets it and the display's
    /// pocket now rest — a timer, its own, since the light is no
    /// motion.
    func flash(
        _ shown: Shown,
        on display: DisplayID,
        for hold: TimeInterval
    ) {
        let mine = (flashGeneration[display] ?? 0) + 1
        flashGeneration[display] = mine
        shown.view.flashing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + hold) {
            [weak self, weak view = shown.view] in
            guard let self, self.flashGeneration[display] == mine
            else { return }
            view?.flashing = false
            // The pocket may have changed form meanwhile.
            guard let spec = self.specs[display],
                let now = self.shown(spec)
            else { return }
            now.view.flashing = false
            self.paintFade(now, spec)
        }
    }

    /// Lights `display`'s pocket for `hold`, and nods it where
    /// `nods`: a play's window landing or leaving, which the play
    /// schedules (`DeferredTasks.Key.pocketLight`).
    func light(_ display: DisplayID, for hold: TimeInterval, nods: Bool) {
        guard let spec = specs[display], let shown = shown(spec) else {
            return
        }
        flash(shown, on: display, for: hold)
        paintFade(shown, spec)
        if nods { shown.view.pocket.nod() }
    }

    /// Fades the empty pocket at rest; a flash shows it full. An
    /// ancestor fades (bars.md ▸ glass alpha): the handle's panel,
    /// or the section's holder.
    func paintFade(_ shown: Shown, _ spec: Spec) {
        let faded = spec.faded && !shown.view.flashing
        let alpha = faded ? Self.fadedAlpha : 1
        shown.panel?.alphaValue = alpha
        shown.holder?.alphaValue = alpha
    }
}
