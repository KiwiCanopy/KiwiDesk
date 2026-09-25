import AppKit

/// Visual drag feedback overlay showing ghost slot and drop
/// zone highlights. Both are borderless click-through panels
/// that never take focus or join the window cycle; frames are
/// AX coordinates, flipped at the AppKit boundary. Under Liquid
/// Glass a marker is glass tinted by its fill, fading downward,
/// with its border kept solid on top (#1620).
@MainActor
public final class DragOverlay {
    /// One marker's panel and the glass it hosts once asked to.
    @MainActor
    final class Marker {
        let panel: NSPanel
        var glass: NSView?
        let tint = GlassBackdrop()

        init(panel: NSPanel) { self.panel = panel }
    }

    private(set) var ghost: Marker?
    private(set) var dropZone: Marker?

    public init() {}

    public var isGhostVisible: Bool {
        ghost?.panel.isVisible ?? false
    }

    public var isDropZoneVisible: Bool {
        dropZone?.panel.isVisible ?? false
    }

    /// Marks the dragged window's home slot in AX coordinates.
    /// `glassBeneath` is the dragged window when the marker is
    /// glass, nil when it is flat: ONE argument, so a glass marker
    /// cannot exist without the window it sits directly beneath,
    /// at that window's level — the glass never blurs the window
    /// in hand (#1620). Flat markers keep the floating level.
    public func showGhost(
        at frame: CGRect,
        style: DragVisual,
        cornerRadius: CGFloat,
        glassBeneath window: CGWindowID?
    ) {
        let marker = ghost ?? Marker(panel: makePanel())
        ghost = marker
        show(
            marker,
            at: frame,
            style: style,
            radius: cornerRadius,
            beneath: window
        )
    }

    /// Marks the swap target's slot in AX coordinates, glass and
    /// ordered like the ghost.
    public func showDropZone(
        at frame: CGRect,
        style: DragVisual,
        cornerRadius: CGFloat,
        glassBeneath window: CGWindowID?
    ) {
        let marker = dropZone ?? Marker(panel: makePanel())
        dropZone = marker
        show(
            marker,
            at: frame,
            style: style,
            radius: cornerRadius,
            beneath: window
        )
        marker.glass?.alphaValue = Self.dropZoneGlassOpacity
    }

    /// The drop zone's glass is thinned: it lies over the window a
    /// drop swaps with, which should stay readable through it
    /// (owner, device 2026-09-25). Opacity is the one public
    /// strength the material takes; `.clear` is already its
    /// lightest style.
    static let dropZoneGlassOpacity: CGFloat = 0.6

    private func show(
        _ marker: Marker,
        at frame: CGRect,
        style: DragVisual,
        radius: CGFloat,
        beneath window: CGWindowID?
    ) {
        place(
            marker.panel,
            at: adjustedFrame(frame, style: style),
            below: window
        )
        apply(style, radius: radius, glass: window != nil, to: marker)
    }

    private func adjustedFrame(
        _ frame: CGRect,
        style: DragVisual
    ) -> CGRect {
        guard style.border else { return frame }
        let offset = style.borderWidth / 2
        switch style.borderAlignment {
        case .inside:
            return frame.insetBy(dx: offset, dy: offset)
        case .outside:
            return frame.insetBy(dx: -offset, dy: -offset)
        }
    }

    public func hideGhost() {
        ghost?.panel.orderOut(nil)
    }

    public func hideDropZone() {
        dropZone?.panel.orderOut(nil)
    }

    public func hideAll() {
        hideGhost()
        hideDropZone()
    }

    /// Sets the frame and orders the panel in: above everything,
    /// or directly beneath `window` at its level.
    private func place(
        _ panel: NSPanel,
        at frame: CGRect,
        below window: CGWindowID?
    ) {
        panel.setFrame(
            GeometryUtils.flip(
                frame,
                primaryHeight: GeometryUtils.primaryHeight
            ),
            display: true
        )
        if let window {
            // Every show, not only on a change: a window raised
            // mid-drag would otherwise bury the marker, which the
            // floating level could never be (the sticky mark's
            // re-order is the same shape).
            panel.level = .normal
            panel.order(.below, relativeTo: Int(window))
            return
        }
        guard !panel.isVisible || panel.level != .floating else {
            return
        }
        panel.level = .floating
        panel.orderFrontRegardless()
    }

    private func apply(
        _ style: DragVisual,
        radius: CGFloat,
        glass: Bool,
        to marker: Marker
    ) {
        guard let container = marker.panel.contentView,
            let layer = container.layer
        else { return }
        layer.cornerRadius = radius
        // A layer's border draws above its sublayers, so it stays
        // solid over the glass (`DragPairSeparationTests`, #511).
        layer.borderWidth = style.border ? style.borderWidth : 0
        layer.borderColor = color(style.borderColor).cgColor
        if glass, let plate = glassView(for: marker) {
            layer.backgroundColor = NSColor.clear.cgColor
            plate.isHidden = false
            GlassPlate.update(
                plate,
                frame: container.bounds,
                cornerRadius: radius
            )
            GlassTint.apply(
                marker.tint,
                below: plate,
                frame: container.bounds,
                cornerRadius: radius,
                hex: style.fill ? style.fillColor : "",
                edge: .top
            )
            return
        }
        marker.glass?.isHidden = true
        marker.tint.isHidden = true
        layer.backgroundColor =
            style.fill
            ? color(style.fillColor).cgColor
            : NSColor.clear.cgColor
    }

    /// The marker's glass, hosted once; nil below macOS 26.
    private func glassView(for marker: Marker) -> NSView? {
        if let glass = marker.glass { return glass }
        guard let glass = GlassPlate.make(),
            let container = marker.panel.contentView
        else { return nil }
        glass.autoresizingMask = [.width, .height]
        marker.tint.autoresizingMask = [.width, .height]
        container.addSubview(glass)
        GlassPlate.setContent(glass, NSView())
        marker.glass = glass
        return glass
    }

    /// Colors come as user-set hex strings; a string that no
    /// longer parses falls back to the system accent color.
    private func color(_ hex: String) -> NSColor {
        guard let c = DragVisual.parseHex(hex) else {
            return .controlAccentColor
        }
        return NSColor(
            srgbRed: c.red,
            green: c.green,
            blue: c.blue,
            alpha: c.alpha
        )
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
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle,
        ]
        let view = NSView()
        view.wantsLayer = true
        panel.contentView = view
        return panel
    }
}
