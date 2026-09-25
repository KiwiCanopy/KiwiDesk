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
    /// Under glass both markers sit directly BELOW `below` — the
    /// dragged window — and above every other window, so their
    /// glass never blurs the window in hand (#1620).
    public func showGhost(
        at frame: CGRect,
        style: DragVisual,
        cornerRadius: CGFloat,
        glass: Bool = false,
        below window: CGWindowID? = nil
    ) {
        let marker = ghost ?? Marker(panel: makePanel())
        ghost = marker
        place(
            marker.panel,
            at: adjustedFrame(frame, style: style),
            below: glass ? window : nil
        )
        apply(style, radius: cornerRadius, glass: glass, to: marker)
    }

    /// Marks the swap target's slot in AX coordinates, ordered
    /// like the ghost.
    public func showDropZone(
        at frame: CGRect,
        style: DragVisual,
        cornerRadius: CGFloat,
        glass: Bool = false,
        below window: CGWindowID? = nil
    ) {
        let marker = dropZone ?? Marker(panel: makePanel())
        dropZone = marker
        place(
            marker.panel,
            at: adjustedFrame(frame, style: style),
            below: glass ? window : nil
        )
        apply(style, radius: cornerRadius, glass: glass, to: marker)
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
        let level: NSWindow.Level = window == nil ? .floating : .normal
        guard !panel.isVisible || panel.level != level else { return }
        panel.level = level
        if let window {
            panel.order(.below, relativeTo: Int(window))
        } else {
            panel.orderFrontRegardless()
        }
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
                hex: style.fill ? style.fillColor : Self.clearFill,
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

    /// A Fill `GlassTint` reads as no colour: clear glass.
    private static let clearFill = "#00000000"

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
