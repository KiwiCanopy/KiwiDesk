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
    /// The pointer, in Cocoa screen coordinates, and the pop-up a
    /// menu at it — the layout picker's (#762). The pop-up waits
    /// for the next turn: its tracking loop is modal, and run inside
    /// the call it would hold a CLI reply and spend a Lua binding's
    /// deadline. Pinned in both `makeTestCore` twins.
    var pointer: @MainActor () -> NSPoint = { NSEvent.mouseLocation }
    var popUp: @MainActor (NSMenu, NSPoint) -> Void = { _, _ in }
    /// When the picker's menu last closed, on `clock`. A hotkey
    /// press reaches Core only once the menu's modal tracking ends,
    /// so a press made while it was open arrives within ms of the
    /// close (measured 3–13 ms, #762) and `pressWasQueued` drops it.
    var pickerClosedAt: TimeInterval?
    var clock: @MainActor () -> TimeInterval = {
        ProcessInfo.processInfo.systemUptime
    }
    static let queuedPressWindow: TimeInterval = 0.15

    init() {
        popUp = { [weak self] menu, point in
            DispatchQueue.main.async {
                let current = menu.items.first { $0.state == .on }
                let at = current == nil ? point : Self.pickerAnchor(point)
                menu.popUp(positioning: current, at: at, in: nil)
                self?.pickerClosedAt = self?.clock()
            }
        }
    }

    /// Whether a picker request is the press made while its menu
    /// was open, rather than a new one.
    func pressWasQueued() -> Bool {
        guard let closed = pickerClosedAt else { return false }
        return clock() - closed < Self.queuedPressWindow
    }

    /// Where the current row's top-left goes so the pointer rests
    /// over that row's symbol rather than on its corner: AppKit
    /// pins the positioning item's top-left to the point (24 pt
    /// rows, macOS 27).
    nonisolated static func pickerAnchor(_ pointer: NSPoint) -> NSPoint {
        NSPoint(x: pointer.x - 32, y: pointer.y + 12)
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
    /// A hit for a point in this view's coordinates that no item
    /// view answers itself — the front-app segment's (#2024).
    var hitAt: (NSPoint) -> BarHit? = { _ in nil }

    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        return contextMenus?.menu(for: hitAt(point) ?? hit)
    }
}
