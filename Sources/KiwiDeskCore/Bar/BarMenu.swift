import AppKit

/// One row of a bar's context menu (#1518), as data: the same list
/// builds the right-click `NSMenu` and VoiceOver's named actions,
/// so both routes offer the same rows (ui-patterns ▸ a row's menu
/// is one menu).
struct BarMenuRow {
    enum Kind {
        case action(@MainActor () -> Void)
        case submenu([BarMenuRow])
        case separator
        /// A section header naming what the rows below act on
        /// (#2024). Drawn in the menu only: VoiceOver's actions
        /// skip it, since it acts on nothing.
        case header
    }

    var title: String
    var kind: Kind
    /// Greyed, never hidden, where the row cannot apply (#802).
    var enabled = true
    var checked = false
    /// An SF Symbol name.
    var symbol: String?
    var subtitle: String?

    static var separator: BarMenuRow {
        BarMenuRow(title: "", kind: .separator)
    }

    static func header(_ title: String) -> BarMenuRow {
        BarMenuRow(title: title, kind: .header)
    }

    static func action(
        _ title: String,
        enabled: Bool = true,
        checked: Bool = false,
        symbol: String? = nil,
        subtitle: String? = nil,
        perform: @escaping @MainActor () -> Void
    ) -> BarMenuRow {
        BarMenuRow(
            title: title,
            kind: .action(perform),
            enabled: enabled,
            checked: checked,
            symbol: symbol,
            subtitle: subtitle
        )
    }

    static func submenu(
        _ title: String,
        enabled: Bool = true,
        symbol: String? = nil,
        _ rows: [BarMenuRow]
    ) -> BarMenuRow {
        BarMenuRow(
            title: title,
            kind: .submenu(rows),
            enabled: enabled,
            symbol: symbol
        )
    }

    var isSeparator: Bool {
        if case .separator = kind { return true }
        return false
    }
}

/// Builds a bar menu's two routes from one row list (#1518).
@MainActor
enum BarMenu {
    /// The `NSMenu`: auto-enabling off at every level, each row
    /// stating `isEnabled` itself (#802).
    static func make(_ rows: [BarMenuRow]) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        for row in rows { menu.addItem(item(row)) }
        return menu
    }

    /// VoiceOver's named actions: every enabled leaf, a nested one
    /// named after its parent and a checked one said to be current,
    /// so the rotor lists what the menu offers and what it holds.
    static func accessibilityActions(
        _ rows: [BarMenuRow],
        parent: String? = nil
    ) -> [NSAccessibilityCustomAction] {
        rows.flatMap { row -> [NSAccessibilityCustomAction] in
            guard row.enabled else { return [] }
            let named =
                parent.map {
                    L("bar.menu.ax.nested", "%1$@: %2$@", $0, row.title)
                } ?? row.title
            let current =
                row.checked
                ? L("space_bar.item.ax.current", "%1$@, current", named)
                : named
            let name =
                row.subtitle.map {
                    L("bar.menu.ax.subtitled", "%1$@, %2$@", current, $0)
                } ?? current
            switch row.kind {
            case .separator, .header:
                return []
            case .submenu(let children):
                return accessibilityActions(children, parent: name)
            case .action(let perform):
                return [
                    NSAccessibilityCustomAction(name: name) {
                        MainActor.assumeIsolated { perform() }
                        return true
                    }
                ]
            }
        }
    }

    private static func item(_ row: BarMenuRow) -> NSMenuItem {
        if row.isSeparator { return .separator() }
        if case .header = row.kind { return .sectionHeader(title: row.title) }
        let item = NSMenuItem(
            title: row.title,
            action: nil,
            keyEquivalent: ""
        )
        item.isEnabled = row.enabled
        item.state = row.checked ? .on : .off
        if let symbol = row.symbol {
            let image = NSImage(
                systemSymbolName: symbol,
                accessibilityDescription: nil
            )
            image?.isTemplate = true
            item.image = image
            SpaceBarWindowMenu.showImage(item)
        }
        if let subtitle = row.subtitle, #available(macOS 14.4, *) {
            item.subtitle = subtitle
        }
        switch row.kind {
        case .separator, .header:
            break
        case .submenu(let rows):
            item.submenu = make(rows)
        case .action(let perform):
            let handler = Handler(perform)
            item.target = handler
            item.action = #selector(Handler.fire(_:))
            // `target` is weak: the row keeps its handler alive
            // for as long as the menu is.
            item.representedObject = handler
        }
        return item
    }

    private final class Handler: NSObject {
        let perform: @MainActor () -> Void

        init(_ perform: @escaping @MainActor () -> Void) {
            self.perform = perform
        }

        @MainActor @objc func fire(_ sender: NSMenuItem) {
            perform()
        }
    }
}
