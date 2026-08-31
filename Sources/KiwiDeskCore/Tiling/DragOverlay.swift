import AppKit

/// Visual drag feedback overlay showing ghost slot and drop
/// zone highlights. Both are borderless click-through panels
/// that never take focus or join the window cycle; frames are
/// AX coordinates, flipped at the AppKit boundary.
@MainActor
public final class DragOverlay {
    private var ghost: NSPanel?
    private var dropZone: NSPanel?

    public init() {}

    public var isGhostVisible: Bool {
        ghost?.isVisible ?? false
    }

    public var isDropZoneVisible: Bool {
        dropZone?.isVisible ?? false
    }

    /// Marks the dragged window's home slot in AX coordinates.
    public func showGhost(
        at frame: CGRect,
        style: DragVisual,
        cornerRadius: CGFloat
    ) {
        let panel = ghost ?? makePanel()
        ghost = panel
        apply(style, radius: cornerRadius, to: panel)
        place(panel, at: adjustedFrame(frame, style: style))
    }

    /// Marks the swap target's slot in AX coordinates.
    public func showDropZone(
        at frame: CGRect,
        style: DragVisual,
        cornerRadius: CGFloat
    ) {
        let panel = dropZone ?? makePanel()
        dropZone = panel
        apply(style, radius: cornerRadius, to: panel)
        place(panel, at: adjustedFrame(frame, style: style))
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
        ghost?.orderOut(nil)
    }

    public func hideDropZone() {
        dropZone?.orderOut(nil)
    }

    public func hideAll() {
        hideGhost()
        hideDropZone()
    }

    private func place(_ panel: NSPanel, at frame: CGRect) {
        panel.setFrame(
            GeometryUtils.flip(
                frame,
                primaryHeight: GeometryUtils.primaryHeight
            ),
            display: true
        )
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    private func apply(
        _ style: DragVisual,
        radius: CGFloat,
        to panel: NSPanel
    ) {
        guard let layer = panel.contentView?.layer else {
            return
        }
        layer.cornerRadius = radius
        layer.borderWidth = style.border ? style.borderWidth : 0
        layer.borderColor = color(style.borderColor).cgColor
        layer.backgroundColor =
            style.fill
            ? color(style.fillColor).cgColor
            : NSColor.clear.cgColor
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
