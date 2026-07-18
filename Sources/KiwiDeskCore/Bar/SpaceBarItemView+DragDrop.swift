import AppKit

/// Drag-drop feedback for one Space item (#372): the synthetic
/// hover tint during a window drag and the pending-spring ring
/// sweep. The dwell timing and the decision to spring live on the
/// driver side; this view only renders the two cues.
extension SpaceBarItemView {

    /// Lights (or clears) the synthetic drag-hover tint — the
    /// same `hoverColor` an ordinary mouse hover shows, driven
    /// from the AX cursor position because tracking areas stay
    /// silent while another app owns the drag.
    func setDragHover(_ on: Bool) {
        guard isDragHovered != on else { return }
        isDragHovered = on
        restyle()
    }

    /// Starts the ring sweep: a `highlightColor` stroke filling
    /// 0→1 over `duration`, sitting on top of the hover tint as
    /// the "this will become active" cue. Reuses the active
    /// indicator's ring vocabulary (2 pt, `highlightColor`).
    func beginSpringSweep(duration: TimeInterval) {
        let inset = springRing.lineWidth / 2
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        springRing.frame = bounds
        springRing.path =
            CGPath(
                roundedRect: bounds.insetBy(dx: inset, dy: inset),
                cornerWidth: cornerRadius,
                cornerHeight: cornerRadius,
                transform: nil
            )
        springRing.strokeColor =
            NSColor(kiwiHex: style.highlightColor).cgColor
        springRing.isHidden = false
        springRing.strokeEnd = 0
        CATransaction.commit()

        let sweep = CABasicAnimation(keyPath: "strokeEnd")
        sweep.fromValue = 0
        sweep.toValue = 1
        sweep.duration = duration
        sweep.timingFunction =
            CAMediaTimingFunction(name: .linear)
        sweep.fillMode = .forwards
        sweep.isRemovedOnCompletion = false
        springRing.strokeEnd = 1
        springRing.add(sweep, forKey: "springSweep")
    }

    /// Cancels a pending sweep and resets the ring — leaving the
    /// item, or the spring firing, both end here (all-or-nothing;
    /// re-entering restarts from zero).
    func cancelSpringSweep() {
        springRing.removeAnimation(forKey: "springSweep")
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        springRing.strokeEnd = 0
        springRing.isHidden = true
        CATransaction.commit()
    }
}
