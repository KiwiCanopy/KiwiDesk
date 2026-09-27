import AppKit

/// The menu a Space Bar glyph group or `+n` opens (#1528): one row
/// per window, handed a list rather than a chip so #1518's
/// right-click rows can reuse it.
@MainActor
enum SpaceBarWindowMenu {
    struct Row: Equatable {
        let window: WindowID
        let app: String
        let title: String
        let icon: NSImage?
        let enabled: Bool
    }

    /// A row's title past this many characters is cut, the whole
    /// title riding the row's tooltip.
    static let titleCap = 60
    static let iconSide: CGFloat = 16

    /// The row's text: the app, then its title where it has one.
    static func text(_ row: Row) -> String {
        guard !row.title.isEmpty else { return row.app }
        return L(
            "space_bar.menu.row",
            "%1$@ — %2$@",
            row.app,
            AppBarStyle.cappedTitle(row.title, to: titleCap)
        )
    }

    static func make(
        _ rows: [Row],
        onPick: @escaping @MainActor (WindowID) -> Void
    ) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let handler = Handler(onPick: onPick)
        for row in rows {
            let item = NSMenuItem(
                title: text(row),
                action: #selector(Handler.pick(_:)),
                keyEquivalent: ""
            )
            item.target = handler
            // `target` is weak: the rows keep the handler alive
            // for as long as the menu is.
            item.representedObject = Pick(row.window, handler)
            item.isEnabled = row.enabled
            if row.title.count > titleCap { item.toolTip = row.title }
            item.image = row.icon.map(scaled)
            showImage(item)
            menu.addItem(item)
        }
        return menu
    }

    /// macOS 27 hides menu-item images unless the item asks
    /// (`preferredImageVisibility`); the SDK CI builds with lacks
    /// the symbol, so it is set through the runtime.
    private static func showImage(_ item: NSMenuItem) {
        let visible = 1  // NSMenuItemImageVisibilityVisible
        guard
            item.responds(
                to: NSSelectorFromString("setPreferredImageVisibility:")
            )
        else { return }
        item.setValue(visible, forKey: "preferredImageVisibility")
    }

    private static func scaled(_ icon: NSImage) -> NSImage {
        let side = NSSize(width: iconSide, height: iconSide)
        let copy = icon.copy() as? NSImage ?? icon
        copy.size = side
        return copy
    }

    private final class Pick: NSObject {
        let window: WindowID
        let handler: Handler
        init(_ window: WindowID, _ handler: Handler) {
            self.window = window
            self.handler = handler
        }
    }

    @MainActor
    private final class Handler: NSObject {
        let onPick: @MainActor (WindowID) -> Void
        init(onPick: @escaping @MainActor (WindowID) -> Void) {
            self.onPick = onPick
        }

        @objc func pick(_ sender: NSMenuItem) {
            guard let pick = sender.representedObject as? Pick else {
                return
            }
            onPick(pick.window)
        }
    }
}
