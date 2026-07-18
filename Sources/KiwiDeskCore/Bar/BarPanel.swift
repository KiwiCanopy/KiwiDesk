import AppKit

/// Shared bar-panel construction (#293): the borderless,
/// non-activating, all-Spaces panel both bar overlays render
/// into. Extracted from `AppBarOverlay.makePanel` when the Space
/// Bar became its second real consumer — each overlay still owns
/// its subview tree and layout.
enum BarPanel {
    /// Like the drag visuals' panels, but clickable. The
    /// `.nonactivatingPanel` mask keeps KiwiDesk out of the key
    /// window order.
    @MainActor
    static func makeNonActivating() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
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
