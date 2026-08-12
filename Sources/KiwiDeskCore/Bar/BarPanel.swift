import AppKit

/// Shared bar-panel construction (#293): the borderless,
/// non-activating, all-Spaces panel both bar overlays render
/// into. Extracted from `AppBarOverlay.makePanel` when the Space
/// Bar became its second real consumer — each overlay still owns
/// its subview tree and layout.
public enum BarPanel {
    /// The level both bars render at.
    ///
    /// **A window that must not be covered by a bar derives its
    /// level from `aboveLevel` rather than writing `.floating`
    /// again.** The two are one fact — "the bars are here, and
    /// this is above them" — and spelled apart they drift the
    /// day the bars move.
    ///
    /// The bars' PEERS are deliberate and stay peers: the drag
    /// overlay (`DragOverlay`) and the shortcuts panel
    /// (`ShortcutsPanelController`) both render at `.floating` of
    /// their own accord, and settling with the bars in raise
    /// order is right for both — a drag visual belongs beside the
    /// bar it is dragging over, and the panel is an overlay the
    /// user summons and dismisses.
    public static let level: NSWindow.Level = .floating

    /// One step above the bars, for a window the user is being
    /// asked to read while tiling runs behind it — the onboarding
    /// tour is what asked for it (#828).
    public static let aboveLevel = NSWindow.Level(
        rawValue: level.rawValue + 1
    )

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
