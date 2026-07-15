import AppKit

/// One window's focus-border ring (#278): a borderless,
/// non-activating, shadowless panel that ignores mouse events and
/// draws a single stroked rounded rect. The manager
/// (`BorderManager`) creates one per bordered window and feeds it
/// geometry; the overlay knows nothing about layouts or focus.
///
/// Non-interactive by design (`ignoresMouseEvents`) — unlike the
/// app bar, a border is never clicked. Sits at the normal window
/// level and is stacked directly above its target window with
/// `order(.above, relativeTo:)` (see `order(above:)`), so a window
/// layered over the target — an ignored panel, a higher-level
/// utility window — stays in front of the ring instead of being
/// covered by it.
@MainActor
final class BorderOverlay {
    private var panel: NSPanel?
    private let shape = CAShapeLayer()

    /// Positions the ring around `geometry.overlayFrame` (AX
    /// coords) and strokes it in `colorHex`. Used both for a
    /// steady-state sync and per animation tick — implicit Core
    /// Animation is disabled so the ring snaps to each commanded
    /// frame instead of easing a step behind the window. Stacking
    /// is left to `order(above:)`, called only on sync (not per
    /// tick) so the ring isn't re-ordered every frame.
    func update(
        geometry: BorderGeometry,
        colorHex: String,
        screen: NSScreen?
    ) {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        panel.setFrame(
            GeometryUtils.flip(
                geometry.overlayFrame,
                primaryHeight: GeometryUtils.primaryHeight
            ),
            display: false
        )
        let bounds = CGRect(
            origin: .zero,
            size: geometry.overlayFrame.size
        )
        shape.frame = bounds
        // Stroke is centered on its path, so inset the path by
        // half the line width to keep the whole stroke inside the
        // overlay bounds.
        let rect = bounds.insetBy(
            dx: geometry.lineWidth / 2,
            dy: geometry.lineWidth / 2
        )
        shape.path = CGPath(
            roundedRect: rect,
            cornerWidth: geometry.cornerRadius,
            cornerHeight: geometry.cornerRadius,
            transform: nil
        )
        shape.lineWidth = geometry.lineWidth
        shape.strokeColor = NSColor(kiwiHex: colorHex).cgColor
        shape.fillColor = NSColor.clear.cgColor
        shape.contentsScale = screen?.backingScaleFactor ?? 2
        CATransaction.commit()
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    /// Stacks the ring directly above its target window in the
    /// global window order (`windowNumber` is the target's
    /// `CGWindowID`). Anything layered over the target — an
    /// ignored panel, a higher-level utility window — therefore
    /// stays in front of the ring. Called on sync, not per tick.
    /// A no-op until the panel exists (first `update` creates it).
    func order(above windowNumber: CGWindowID) {
        panel?.order(.above, relativeTo: Int(windowNumber))
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        // Normal window level (not floating): the ring is stacked
        // relative to its target by `order(above:)`, so it must
        // share the target's band to sit *below* windows layered
        // over it — a floating level would force it above them.
        panel.level = .normal
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        // Stay on the window's own Space; a fullscreen window
        // gets no border (auxiliary only). Not cycled by the app
        // switcher.
        panel.collectionBehavior = [
            .fullScreenAuxiliary,
            .ignoresCycle,
        ]
        let view = NSView()
        view.wantsLayer = true
        view.layer?.addSublayer(shape)
        panel.contentView = view
        return panel
    }
}
