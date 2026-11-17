import AppKit

/// The One-window pocket coming out of its edge and going back in
/// (#2793): out of sight at rest, it slides out of the bar or the
/// screen edge it stands on, and its panel orders out only once the
/// slide back has landed.
extension PocketPlateOverlay {
    /// How deep `spec`'s frame is across its edge: the travel that
    /// takes its mark wholly past the panel's edge-side bound.
    static func depth(of spec: Spec) -> CGFloat {
        let horizontal = spec.handle?.isHorizontal ?? true
        return horizontal ? spec.frame.height : spec.frame.width
    }

    /// Slides `shown`, whose pocket was `old`, back into its edge and
    /// orders its panel out on landing, unless it returns meanwhile.
    /// False where no slide plays, so the caller orders it out now.
    func leave(_ shown: Shown, _ old: Spec) -> Bool {
        guard let panel = shown.panel, isOnScreen(panel),
            let edge = old.handle
        else { return false }
        let span = BarMotion.playPocketEntrance(
            shown.view,
            edge: edge,
            travel: Self.depth(of: old),
            entering: false
        )
        guard span > 0 else { return false }
        let token = UUID()
        let display = old.display
        leaving[display] = token
        afterLeave(span) { [weak self] in
            guard let self, self.leaving[display] == token else { return }
            self.leaving[display] = nil
            self.orderOut(shown, on: display)
            shown.view.layer?.removeAnimation(forKey: "pocketEntrance")
        }
        return true
    }

    /// Orders `shown`'s panel out and drops its hover: an ordered-out
    /// handle hears no exit (#2678 review 20); a section's hover on
    /// that display stays its own.
    func orderOut(_ shown: Shown, on display: DisplayID) {
        shown.panel?.orderOut(nil)
        if shown.view.dropHover() { hovered.remove(display) }
    }

    /// Lands the sink `shown`'s view runs (#3368, #3383): once it
    /// has run, the pocket hides in its handle and the panel takes the
    /// spec's resting frame, unless a newer sink or a rise took the
    /// view meanwhile — the view's token decides.
    func landSink(
        _ shown: Shown,
        on display: DisplayID,
        after span: TimeInterval
    ) {
        guard let token = shown.view.sink else { return }
        afterLeave(span) { [weak self] in
            guard let self, let spec = self.specs[display],
                let shown = self.shown(spec), shown.view.sink == token
            else { return }
            shown.view.endSink(token)
            Self.place(shown, at: spec.frame)
        }
    }

    /// Whether a handle at rest in `spec` keeps the risen room for a
    /// sink: it was rising or risen in `old`, or its sink still runs.
    static func holdsRisenRoom(
        _ spec: Spec,
        old: Spec?,
        shown: Shown
    ) -> Bool {
        spec.handle != nil && !spec.whole && spec.rise == nil
            && !spec.risen
            && (old?.rise != nil || old?.risen == true
                || shown.view.sinking)
    }

    /// Sizes a handle's panel, and its view, to `frame`.
    static func place(_ shown: Shown, at frame: CGRect) {
        guard let panel = shown.panel else { return }
        if panel.frame != frame { panel.setFrame(frame, display: false) }
        shown.view.frame = CGRect(origin: .zero, size: frame.size)
    }
}
