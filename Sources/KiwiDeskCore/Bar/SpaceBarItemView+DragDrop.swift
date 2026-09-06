import AppKit

/// Drag-drop hover and spring-sweep feedback rendering for
/// SpaceBarItemView (#372).
extension SpaceBarItemView {
    /// Toggles synthetic drag hover highlight, driven from the AX
    /// cursor position — tracking areas stay silent while another
    /// app owns the drag.
    func setDragHover(_ on: Bool) {
        guard isDragHovered != on else { return }
        isDragHovered = on
        restyle()
    }

    /// Starts spring-loaded ring sweep animation (#372).
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
        // The ring's resting value is WHOLE and the animation is
        // what keeps it empty, so both are written inside the
        // disabled-actions transaction: a bare `strokeEnd = 1`
        // on this hand-added sublayer starts an implicit 0.25 s
        // stroke of its own, racing the one we add (#1078
        // review). An explicit `add` still runs here.
        springRing.strokeEnd = 1
        springRing.add(
            BarMotion.springSweep(fill: duration, delay: delay),
            forKey: "springSweep"
        )
        CATransaction.commit()
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
