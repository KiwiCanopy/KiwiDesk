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
        guard let panel = shown.panel, panel.isVisible,
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
        leaving[old.display] = token
        let display = old.display
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(span))
            guard let self, self.leaving[display] == token else { return }
            self.leaving[display] = nil
            panel.orderOut(nil)
            shown.view.layer?.removeAnimation(forKey: "pocketEntrance")
        }
        return true
    }
}
