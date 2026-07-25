import AppKit

/// One window's focus-border ring (#278): a borderless,
/// non-activating, shadowless panel that ignores mouse events and
/// draws a single stroked rounded rect. The manager
/// (`BorderManager`) creates one per bordered window and feeds it
/// geometry; the overlay knows nothing about layouts or focus.
///
/// Non-interactive by design (`ignoresMouseEvents`) — unlike the
/// app bar, a border is never clicked. Sits at the normal window
/// level and is stacked directly behind its target window with
/// `order(.below, relativeTo:)` (see `order(relativeTo:)`). The stroke's
/// inner overlap sits under the target while its outward reach stays
/// visible; child panels and other windows above the target therefore
/// cover the ring naturally. The mandatory AppKit fallback for the
/// SkyLight fast path — `BorderOverlay` swaps to one on any private
/// surface failure — so it is module-internal, not file-private.
@MainActor
final class AppKitBorderOverlay: BorderOverlayBackend {
    private var panel: NSPanel?
    private let shape = CAShapeLayer()

    /// The AppKit panel stacks below its target (it cannot express a
    /// SkyLight sub-level, so `above` here would paint over child
    /// popovers — the #320 regression). Below keeps that occlusion
    /// correct at the cost of the rounded corner seam, which only
    /// the SkyLight `above` path fixes.
    let orderMode: BorderGeometry.Order = .below

    /// Positions the ring around `geometry.overlayFrame` (AX
    /// coords) and strokes it in `colorHex`. Used both for a
    /// steady-state sync and per animation tick — implicit Core
    /// Animation is disabled so the ring snaps to each commanded
    /// frame instead of easing a step behind the window. Stacking
    /// is left to `order(relativeTo:)`, called only on sync (not per
    /// tick) so the ring isn't re-ordered every frame.
    func update(
        geometry: BorderGeometry,
        colorHex: String,
        screen: NSScreen?
    ) -> Bool {
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
        // Stroke is centered on its path, so inset the path by half
        // the line width to keep the whole stroke inside the overlay
        // bounds — plus `glowMargin` (0 without glow) so the ring
        // stays put in the grown frame and the margin is bloom room
        // (#358).
        let inset = geometry.glowMargin + geometry.lineWidth / 2
        let rect = bounds.insetBy(dx: inset, dy: inset)
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
        applyGlow(geometry: geometry, rect: rect, colorHex: colorHex)
        CATransaction.commit()
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
        return true
    }

    /// The glow bloom on the fallback ring (#358). The shadow is
    /// cast from a **filled** outer rounded-rect `shadowPath`, not
    /// the thin stroke, so the bloom is a solid halo instead of a
    /// banded contour smear. Below-order occludes the inward half of
    /// the bloom behind the window, so only the outward bloom shows
    /// — matching the SkyLight path. `masksToBounds` stays false so
    /// the halo can spill past the shape into the grown frame.
    private func applyGlow(
        geometry: BorderGeometry,
        rect: CGRect,
        colorHex: String
    ) {
        guard geometry.glowMargin > 0 else {
            shape.shadowOpacity = 0
            shape.shadowColor = nil
            shape.shadowPath = nil
            return
        }
        let half = geometry.lineWidth / 2
        let radius = geometry.cornerRadius
        let outerRadius = radius <= 0 ? 0 : radius + half
        shape.shadowColor = NSColor.kiwiGlow(hex: colorHex)
        shape.shadowRadius = geometry.glowMargin
        shape.shadowOpacity = 1
        shape.shadowOffset = .zero
        shape.shadowPath = CGPath(
            roundedRect: rect.insetBy(dx: -half, dy: -half),
            cornerWidth: outerRadius,
            cornerHeight: outerRadius,
            transform: nil
        )
    }

    /// Stacks the ring directly behind its target window in the
    /// global window order (`windowNumber` is the target's
    /// `CGWindowID`). Anything layered over the target — an
    /// ignored panel, a higher-level utility window — therefore
    /// stays in front of the ring. Called on sync, not per tick.
    /// A no-op until the panel exists (first `update` creates it).
    func order(relativeTo windowNumber: CGWindowID) -> Bool {
        panel?.order(.below, relativeTo: Int(windowNumber))
        return true
    }

    func hide() -> Bool {
        panel?.orderOut(nil)
        return true
    }

    private func makePanel() -> NSPanel {
        // A frame-constraining panel would clamp a top-row ring's
        // upward dead-end bump to zero (#436) — see BorderOverlayPanel.
        let panel = BorderOverlayPanel(
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
        // relative to its target by `order(relativeTo:)`, so it must
        // share the target's band to sit *below* windows layered
        // over it — a floating level would force it above them.
        panel.level = .normal
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        // A fullscreen window gets no border (auxiliary only); not
        // cycled by the app switcher. `.transient` hides this AppKit
        // fallback ring in Exposé/Mission Control at the compositor
        // level so it vanishes with the swipe — the SkyLight fast
        // path self-vanishes via its space pin, and this hint gives
        // the fallback ring the same instant behavior.
        panel.collectionBehavior = [
            .transient,
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
