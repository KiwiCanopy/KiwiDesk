import AppKit

/// One window's focus-border ring (#278): a borderless,
/// non-activating, shadowless panel that ignores mouse events and
/// draws a single stroked rounded rect. The manager
/// (`BorderManager`) creates one per bordered window and feeds it
/// geometry; the overlay knows nothing about layouts or focus.
///
/// Non-interactive by design (`ignoresMouseEvents`) — unlike the
/// app bar, a border is never clicked. Sits at `.floating`, the
/// same level as the app bar and drag visuals; tiled windows
/// don't overlap, so a ring above them never buries a neighbor.
@MainActor
final class BorderOverlay {
    private var panel: NSPanel?
    private let shape = CAShapeLayer()

    /// Positions the ring around `geometry.overlayFrame` (AX
    /// coords) and strokes it in `colorHex`. Used both for a
    /// steady-state sync and per animation tick — implicit Core
    /// Animation is disabled so the ring snaps to each commanded
    /// frame instead of easing a step behind the window.
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
        panel.level = .floating
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
