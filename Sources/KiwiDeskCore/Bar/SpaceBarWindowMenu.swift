import AppKit

/// The menu of a Space Bar glyph group's or `+n`'s windows — the
/// peek's twin, opened by VoiceOver's press and "N more" (#1528,
/// #1946): one row
/// per window, handed a list rather than a chip so #1518's
/// right-click rows can reuse it. A glyph's rows are one app's, so
/// they list titles under an app header; `+n`'s mix apps and keep
/// the icon and name (#1947).
@MainActor
enum SpaceBarWindowMenu {
    /// A window as the bar lists name it, and what only the menu
    /// adds: whether the focus door would take it (#1345).
    struct Row: Equatable {
        let row: BarWindowRow
        let enabled: Bool
    }

    /// A row's title past this many characters is cut, the whole
    /// title riding the row's tooltip.
    static let titleCap = 60
    static let iconSide: CGFloat = 16

    /// A window named by its title alone — a glyph row here, a
    /// window submenu of the bars' right-click menus — or, untitled,
    /// by a placeholder rather than left blank (#1947).
    static func windowName(_ title: String) -> String {
        title.isEmpty
            ? L("space_bar.menu.untitled", "Untitled Window") : title
    }

    /// A glyph row's text: its window's name, capped.
    static func titleText(_ row: BarWindowRow) -> String {
        AppBarStyle.cappedTitle(windowName(row.title), to: titleCap)
    }

    /// An overflow row's text: the app, then its title where it
    /// has one.
    static func text(_ row: BarWindowRow) -> String {
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
        kind: SpaceBarGlyphPick.Kind,
        onPick: @escaping @MainActor (WindowID) -> Void
    ) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let handler = Handler(onPick: onPick)
        let oneApp = kind == .glyph
        if oneApp, let app = rows.first?.row.app {
            menu.addItem(.sectionHeader(title: app))
        }
        for entry in rows {
            let row = entry.row
            let item = NSMenuItem(
                title: oneApp ? titleText(row) : text(row),
                action: #selector(Handler.pick(_:)),
                keyEquivalent: ""
            )
            item.target = handler
            // `target` is weak: the rows keep the handler alive
            // for as long as the menu is.
            item.representedObject = Pick(row.window, handler)
            item.isEnabled = entry.enabled
            if row.title.count > titleCap { item.toolTip = row.title }
            if !oneApp {
                item.image = row.icon.map(scaled)
                showImage(item)
            }
            menu.addItem(item)
        }
        return menu
    }

    /// macOS 27 hides menu-item images unless the item asks
    /// (`preferredImageVisibility`); the SDK CI builds with lacks
    /// the symbol, so it is set through the runtime.
    static func showImage(_ item: NSMenuItem) {
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
