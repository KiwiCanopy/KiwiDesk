import AppKit

/// What a right-click on the shelf landed on (#1518): the one
/// question that picks a menu's rows above its shelf section.
enum BarHit: Equatable {
    /// A Space Bar item.
    case space(SpaceID)
    /// A chip's `+N` disc.
    case disc(SpaceID)
    /// An app glyph on a Space item: the windows it stands for,
    /// in row order.
    case glyph([WindowID])
    /// An App Bar item: its window, or a collapsed group's.
    case appItem([WindowID])
    /// A section's overflow count.
    case count
    /// The divider between two bars sharing an edge.
    case divider
    /// Empty bar space: a section's background or the plate.
    case empty
}

/// The bars' context menus (#1518) — Core's one instance, handed
/// to every bar view that answers a right-click. `rows` is Core's
/// (`KiwiCore+BarMenus`); a view asks here for its menu and its
/// VoiceOver actions, so the two routes read one row list.
@MainActor
final class BarContextMenus {
    var rows: (BarHit) -> [BarMenuRow] = { _ in [] }
    /// What the rows ask of the GUI; `KiwiCore.barMenuHooks`.
    var hooks = BarMenuHooks()
    /// Quit ‹App›: the app handles its own unsaved work, KiwiDesk
    /// asks nothing (#1518). Pinned inert in `makeTestCore`.
    var terminateApp: @MainActor (pid_t) -> Void = {
        NSRunningApplication(processIdentifier: $0)?.terminate()
    }

    func menu(for hit: BarHit) -> NSMenu? {
        let rows = rows(hit)
        return rows.isEmpty ? nil : BarMenu.make(rows)
    }

    func accessibilityActions(
        for hit: BarHit
    ) -> [NSAccessibilityCustomAction] {
        BarMenu.accessibilityActions(rows(hit))
    }
}

extension NSView {
    /// The menu source of the nearest bar surface above this view
    /// (#1518): a section root or the shelf's own, which its overlay
    /// sets — the one holder, so no view between can drop it.
    var barContextMenus: BarContextMenus? {
        var view = superview
        while let current = view {
            if let surface = current as? BarMenuView {
                return surface.contextMenus
            }
            view = current.superview
        }
        return nil
    }
}

/// A flipped bar view whose right-click opens the menu for `hit`:
/// a section's root and the shelf's own surface, which a click
/// reaches when no item under the pointer answers it.
@MainActor
class BarMenuView: AppBarOverlay.FlippedView {
    weak var contextMenus: BarContextMenus?
    var hit = BarHit.empty

    override func menu(for event: NSEvent) -> NSMenu? {
        contextMenus?.menu(for: hit)
    }
}
