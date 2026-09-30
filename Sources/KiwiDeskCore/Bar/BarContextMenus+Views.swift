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
    /// A `+N` disc's, or an app glyph's window rows.
    var menuHit: BarHit {
        kind == .overflow ? .disc(space) : .glyph(members)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        barContextMenus?.menu(for: menuHit)
    }

    override func accessibilityCustomActions()
        -> [NSAccessibilityCustomAction]?
    {
        barContextMenus?.accessibilityActions(for: menuHit)
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

/// An App Bar item's window rows, or a collapsed group's (#1518).
extension AppBarItemView {
    var menuHit: BarHit { .appItem(members) }

    override func menu(for event: NSEvent) -> NSMenu? {
        barContextMenus?.menu(for: menuHit)
    }

    override func accessibilityCustomActions()
        -> [NSAccessibilityCustomAction]?
    {
        barContextMenus?.accessibilityActions(for: menuHit)
    }
}

/// A Control-click opens what a right-click would (#1518). AppKit
/// turns one into a context menu only for a view that leaves
/// `mouseDown` alone, and every bar view that takes a press — to
/// focus, page or drag — asks here first.
extension NSView {
    /// The menu a Control-click opens here: this view's own, else
    /// the nearest one above that answers, as a right-click's falls
    /// through.
    func controlClickMenu(_ event: NSEvent) -> NSMenu? {
        guard event.modifierFlags.contains(.control) else { return nil }
        var view: NSView? = self
        while let current = view {
            if let menu = current.menu(for: event) { return menu }
            view = current.superview
        }
        return nil
    }

    /// Opens the Control-click menu, answering whether it did.
    func openControlClickMenu(_ event: NSEvent) -> Bool {
        guard let menu = controlClickMenu(event) else { return false }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
        return true
    }
}
