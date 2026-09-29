import AppKit

/// Each bar view that answers a right-click (#1518): its hit, its
/// menu, and the same rows as VoiceOver actions. A view with no
/// menu of its own answers nil, and the click falls through to its
/// section root, whose menu is the shelf section's.
extension SpaceBarItemView {
    var menuHit: BarHit? { space.map(BarHit.space) }

    override func menu(for event: NSEvent) -> NSMenu? {
        menuHit.flatMap { barContextMenus?.menu(for: $0) }
    }

    override func accessibilityCustomActions()
        -> [NSAccessibilityCustomAction]?
    {
        menuHit.map { barContextMenus?.accessibilityActions(for: $0) ?? [] }
    }
}

extension SpaceBarGlyphTarget {
    /// A `+N` disc's; a glyph answers nothing yet, so its click
    /// reaches the chip.
    var menuHit: BarHit? { kind == .overflow ? .disc(space) : nil }

    override func menu(for event: NSEvent) -> NSMenu? {
        menuHit.flatMap { barContextMenus?.menu(for: $0) }
    }

    /// A glyph speaks the chip's rows, the ones its right-click
    /// falls through to.
    override func accessibilityCustomActions()
        -> [NSAccessibilityCustomAction]?
    {
        barContextMenus?.accessibilityActions(for: menuHit ?? .space(space))
    }
}

extension ShelfCountView {
    override func menu(for event: NSEvent) -> NSMenu? {
        barContextMenus?.menu(for: .count)
    }

    override func accessibilityCustomActions()
        -> [NSAccessibilityCustomAction]?
    {
        barContextMenus?.accessibilityActions(for: .count)
    }
}

extension ShelfDividerHandle {
    override func menu(for event: NSEvent) -> NSMenu? {
        barContextMenus?.menu(for: .divider)
    }

    override func accessibilityCustomActions()
        -> [NSAccessibilityCustomAction]?
    {
        barContextMenus?.accessibilityActions(for: .divider)
    }
}

/// An App Bar item speaks the shelf section to VoiceOver as its
/// right-click shows it (#1518); its own window rows come with the
/// App Bar's menu.
extension AppBarItemView {
    override func accessibilityCustomActions()
        -> [NSAccessibilityCustomAction]?
    {
        barContextMenus?.accessibilityActions(for: .empty)
    }
}
