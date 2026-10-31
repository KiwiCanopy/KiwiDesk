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

    /// Sizes `shown` to `spec`'s frame, or once a peek taken back has
    /// had its `hoverGrow` where `peekLands`; a later show drops that
    /// landing (#2807).
    func hold(_ shown: Shown, at spec: Spec, until peekLands: Bool) {
        let token = UUID()
        peekHolds[spec.display] = peekLands ? token : nil
        guard peekLands else {
            Self.place(shown, at: spec.frame)
            return
        }
        afterLeave(BarMotion.hoverGrow) { [weak self] in
            guard let self, self.peekHolds[spec.display] == token else {
                return
            }
            self.peekHolds[spec.display] = nil
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
