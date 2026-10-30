import AppKit

/// Shared panel creation and window level constants for bar overlays (#293).
public enum BarPanel {
    /// Window level where bar overlays render (`DragOverlay`,
    /// `JumpPanelController`, the pocket's section and handle
    /// panels at rest).
    public static let level: NSWindow.Level = .floating

    /// Window level one step above bars: modal onboarding overlays
    /// (#828), and the pocket while a window drag runs.
    public static let aboveLevel = NSWindow.Level(
        rawValue: level.rawValue + 1
    )

    /// The pocket's level: above the drag's ghost and drop zone,
    /// which share the bars' level, while a window drag runs (#2776).
    static func pocketLevel(duringDrag: Bool) -> NSWindow.Level {
        duringDrag ? aboveLevel : level
    }

    /// Creates non-activating, transparent, all-spaces panel for bar overlays.
    @MainActor
    static func makeNonActivating() -> NSPanel {
        configure(
            NSPanel(
                contentRect: .zero,
                styleMask: styleMask,
                backing: .buffered,
                defer: true
            )
        )
    }

    /// The bar overlays' panel style.
    static let styleMask: NSWindow.StyleMask = [
        .borderless, .nonactivatingPanel,
    ]

    /// Makes `panel` a bar overlay's — a subclass's too.
    @MainActor
    static func configure<Panel: NSPanel>(_ panel: Panel) -> Panel {
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
