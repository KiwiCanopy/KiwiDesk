import AppKit

/// Visual drag feedback: the ghost at the dragged window's home slot
/// and the drop zone at the slot a drop would swap with (#2797).
/// Both are borderless click-through panels that never take focus or
/// join the window cycle; frames are AX coordinates, flipped at the
/// AppKit boundary.
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

        /// AppKit keeps a visible panel alive after its owner is
        /// gone, so a dropped marker would stay on screen (#1868).
        isolated deinit {
            panel.orderOut(nil)
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

    /// Marks the dragged window's home slot in AX coordinates, the
    /// panel directly beneath `window`, the window being dragged.
    public func showGhost(
        at frame: CGRect,
        cornerRadius: CGFloat,
        beneath window: CGWindowID
    ) {
        let marker = ghost ?? Marker(panel: makePanel())
        ghost = marker
        place(marker.panel, at: frame, below: window)
        marker.view.render(
            .ghost,
            cornerRadius: cornerRadius,
            surface: .flat
        )
    }

    /// Marks the swap target's slot in AX coordinates, ordered like
    /// the ghost. `glass` is the stored leaf already resolved through
    /// `LiquidGlassGate.rendered(glass:)`.
    public func showDropZone(
        at frame: CGRect,
        cornerRadius: CGFloat,
        glass: Bool,
        beneath window: CGWindowID
    ) {
        let marker = dropZone ?? Marker(panel: makePanel())
        dropZone = marker
        place(marker.panel, at: frame, below: window)
        marker.view.render(
            .dropZone,
            cornerRadius: cornerRadius,
            surface: DragMarkerView.surface(glass: glass)
        )
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

    /// Sets the frame and orders the panel in at the normal level,
    /// directly beneath `window`: never over a bar or the pocket, and
    /// never blurring the window in hand (#1620, #2797).
    private func place(
        _ panel: NSPanel,
        at frame: CGRect,
        below window: CGWindowID
    ) {
        panel.setFrame(
            GeometryUtils.flip(
                frame,
                primaryHeight: GeometryUtils.primaryHeight
            ),
            display: true
        )
        // Every show, not only on a change: a window raised mid-drag
        // would otherwise bury the marker (the sticky mark's
        // re-order is the same shape).
        panel.level = .normal
        panel.order(.below, relativeTo: Int(window))
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
        panel.level = .normal
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
