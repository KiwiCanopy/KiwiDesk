import AppKit

/// Shared bar-panel construction (#293): the borderless,
/// non-activating, all-Spaces panel both bar overlays render
/// into. Extracted from `AppBarOverlay.makePanel` when the Space
/// Bar became its second real consumer — each overlay still owns
/// its subview tree and layout.
public enum BarPanel {
    /// The level both bars render at, named once so a window that
    /// must sit above them derives its own from it rather than
    /// restating `.floating` (`NSWindow.Level.aboveBarPanels`).
    public static let level: NSWindow.Level = .floating

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
        panel.level = level
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        // `.transient` hides the bars in Exposé/Mission Control at
        // the compositor level, so they vanish with the swipe and
        // restore on exit with no handler latency; `.canJoinAllSpaces`
        // (orthogonal) still spans every Space.
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .transient,
            .fullScreenAuxiliary,
            .ignoresCycle,
        ]
        return panel
    }
}

extension NSWindow.Level {
    /// One step above the bars, DERIVED from `BarPanel.level`
    /// rather than written as `.floating` a second time — a
    /// window that must not be covered by a bar and a bar that
    /// moved level would otherwise be two facts that can
    /// disagree. The onboarding tour is the one consumer (#828).
    public static let aboveBarPanels = NSWindow.Level(
        rawValue: BarPanel.level.rawValue + 1
    )
}
