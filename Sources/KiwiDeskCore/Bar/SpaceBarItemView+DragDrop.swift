import AppKit

/// Drag-drop feedback for one Space item (#372): the synthetic
/// hover tint during a window drag and the pending-spring ring
/// sweep. The dwell timing and the decision to spring live on the
/// driver side; this view only renders the two cues.
extension SpaceBarItemView {

    /// Lights (or clears) the synthetic drag-hover tint — the
    /// same `hoverFillColor` an ordinary mouse hover shows, driven
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
    func beginSpringSweep(
        duration: TimeInterval,
        delay: TimeInterval
    ) {
        // Track the accent it morphs into: flush box ring when
        // Boxed, the inset capsule on Plain/Liquid Glass (QA
        // 2026-07-19 — a square sweep would poke past the hug
        // plate's corners exactly like the old square accent).
        let boxed = style.hasBox
        var inset = springRing.lineWidth / 2
        if !boxed { inset += BarAccent.capsuleInset }
        let rect = bounds.insetBy(dx: inset, dy: inset)
        let radius =
            boxed
            ? cornerRadius
            : min(rect.width, rect.height) / 2
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        springRing.frame = bounds
        springRing.path =
            CGPath(
                roundedRect: rect,
                cornerWidth: radius,
                cornerHeight: radius,
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
        // Stay empty for `delay` first: `.both` shows the
        // fromValue (0) before beginTime, so a quick flick shows
        // no ring until the hold is deliberate (#372 QA).
        sweep.beginTime = CACurrentMediaTime() + delay
        sweep.timingFunction =
            CAMediaTimingFunction(name: .linear)
        sweep.fillMode = .both
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
