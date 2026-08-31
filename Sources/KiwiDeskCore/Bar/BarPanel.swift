import AppKit

/// Shared panel creation and window level constants for bar overlays (#293).
public enum BarPanel {
    /// Window level where bar overlays render (`DragOverlay`,
    /// `ShortcutsPanelController`).
    public static let level: NSWindow.Level = .floating

    /// Window level one step above bars for modal onboarding overlays (#828).
    public static let aboveLevel = NSWindow.Level(
        rawValue: level.rawValue + 1
    )

    /// Creates non-activating, transparent, all-spaces panel for bar overlays.
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
        panel.level = level
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        // .transient hides bars in Mission Control;
        // .canJoinAllSpaces spans Spaces.
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .transient,
            .fullScreenAuxiliary,
            .ignoresCycle,
        ]
        return panel
    }
}
