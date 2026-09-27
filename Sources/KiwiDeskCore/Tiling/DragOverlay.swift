import AppKit

/// Visual drag feedback overlay showing ghost slot and drop
/// zone highlights. Both are borderless click-through panels
/// that never take focus or join the window cycle; frames are
/// AX coordinates, flipped at the AppKit boundary. Under Liquid
/// Glass a marker is glass tinted by its fill, fading downward,
/// with its border kept solid on top (#1620).
@MainActor
public final class DragOverlay {
    /// One marker's panel and the drawing it hosts.
    @MainActor
    final class Marker {
        let panel: NSPanel
        let view = DragMarkerView()
        var glass: NSView? { view.glass }
        var tint: GlassBackdrop { view.tint }

        init(panel: NSPanel) {
            self.panel = panel
            panel.contentView = view
        }
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
    /// cannot exist without the window it sits directly beneath —
    /// at the normal level, re-ordered there on every show — so the
    /// glass never blurs the window in hand (#1620). Flat markers
    /// keep the floating level.
    public func showGhost(
        at frame: CGRect,
        style: DragVisual,
        cornerRadius: CGFloat,
        glassBeneath window: CGWindowID?,
        sheen: Bool = false
    ) {
        let marker = ghost ?? Marker(panel: makePanel())
        ghost = marker
        show(
            marker,
            at: frame,
            style: style,
            radius: cornerRadius,
            beneath: window,
            sheen: sheen
        )
    }

    /// Marks the swap target's slot in AX coordinates, glass and
    /// ordered like the ghost.
    public func showDropZone(
        at frame: CGRect,
        style: DragVisual,
        cornerRadius: CGFloat,
        glassBeneath window: CGWindowID?,
        sheen: Bool = false
    ) {
        let marker = dropZone ?? Marker(panel: makePanel())
        dropZone = marker
        show(
            marker,
            at: frame,
            style: style,
            radius: cornerRadius,
            beneath: window,
            sheen: sheen
        )
    }

    private func show(
        _ marker: Marker,
        at frame: CGRect,
        style: DragVisual,
        radius: CGFloat,
        beneath window: CGWindowID?,
        sheen: Bool
    ) {
        place(
            marker.panel,
            at: adjustedFrame(frame, style: style),
            below: window
        )
        marker.view.render(
            style,
            radius: radius,
            glass: window != nil,
            sheen: sheen
        )
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
    /// or directly beneath `window` at the normal level.
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
        return panel
    }
}
