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

    /// Lands a rise taken back (#3368): once its sink has run, the
    /// pocket hides in its handle and the panel takes the spec's
    /// resting frame, unless a rise came back meanwhile.
    func landSink(on display: DisplayID, after span: TimeInterval) {
        let token = UUID()
        sinks[display] = token
        afterLeave(span) { [weak self] in
            guard let self, self.sinks[display] == token else { return }
            self.sinks[display] = nil
            guard let spec = self.specs[display],
                let shown = self.shown(spec), shown.view.sinking
            else { return }
            shown.view.endSink()
            Self.place(shown, at: spec.frame)
        }
    }

    /// Sizes a handle's panel, and its view, to `frame`.
    static func place(_ shown: Shown, at frame: CGRect) {
        guard let panel = shown.panel else { return }
        if panel.frame != frame { panel.setFrame(frame, display: false) }
        shown.view.frame = CGRect(origin: .zero, size: frame.size)
    }
}
