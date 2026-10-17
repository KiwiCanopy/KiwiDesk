import AppKit
import KiwiDeskCore

/// Builds the application menu bar to provide standard File, Edit
/// and Window key equivalents (#9, #329, #1533).
@MainActor
enum MainMenu {
    /// The App menu's "Settings…" item routes here; the delegate
    /// opens the dashboard just as the quick menu does.
    static func make(
        settingsTarget: AnyObject,
        settingsAction: Selector
    ) -> NSMenu {
        let bar = NSMenu()
        bar.addItem(
            appMenu(target: settingsTarget, action: settingsAction)
        )
        bar.addItem(fileMenu())
        bar.addItem(editMenu())
        bar.addItem(windowMenu())
        return bar
    }

    /// The submenus a non-activating key panel hands its chords to
    /// (owner ruling 2026-10-13, #1875): File and Edit alone, so
    /// ⌘Q, ⌘H or ⌘, aimed at the app in front never quits, hides
    /// or opens KiwiDesk while a panel holds the keyboard.
    static let panelChordMenus = [fileMenuID, editMenuID]
    static let fileMenuID = NSUserInterfaceItemIdentifier(
        "kiwidesk.menu.file"
    )
    static let editMenuID = NSUserInterfaceItemIdentifier(
        "kiwidesk.menu.edit"
    )

    /// Hands `event` to the panel chord submenus of `bar`; true
    /// where one of them performed it.
    static func performPanelChord(
        _ event: NSEvent,
        in bar: NSMenu? = NSApplication.shared.mainMenu
    ) -> Bool {
        guard let bar else { return false }
        return bar.items.contains { item in
            guard let id = item.identifier,
                panelChordMenus.contains(id),
                let menu = item.submenu
            else { return false }
            return menu.performKeyEquivalent(with: event)
        }
    }

    /// Whether any item of `bar` carries `event`'s chord — the
    /// chords a key panel swallows rather than lets AppKit hand to
    /// KiwiDesk's other menus.
    static func holdsChord(
        _ event: NSEvent,
        in bar: NSMenu? = NSApplication.shared.mainMenu
    ) -> Bool {
        guard let bar,
            let key = event.charactersIgnoringModifiers?.lowercased()
        else { return false }
        let mask: NSEvent.ModifierFlags = [
            .command, .shift, .option, .control,
        ]
        let held = event.modifierFlags.intersection(mask)
        func holds(_ menu: NSMenu) -> Bool {
            menu.items.contains { item in
                if let sub = item.submenu, holds(sub) { return true }
                return !item.keyEquivalent.isEmpty
                    && item.keyEquivalent.lowercased() == key
                    && item.keyEquivalentModifierMask.intersection(mask)
                        == held
            }
        }
        return holds(bar)
    }

    private static func submenu(_ title: String) -> NSMenuItem {
        let item = NSMenuItem()
        item.submenu = NSMenu(title: title)
        return item
    }

    private static func appMenu(
        target: AnyObject,
        action: Selector
    ) -> NSMenuItem {
        let name = L("app.name", "KiwiDesk")
        let item = submenu(name)
        let menu = item.submenu!
        menu.addItem(
            withTitle: L(
                "menu.app.about",
                "About %1$@",
                name
            ),
            action: #selector(
                NSApplication.orderFrontStandardAboutPanel(_:)
            ),
            keyEquivalent: ""
        )
        menu.addItem(.separator())
        let settings = menu.addItem(
            // Shares the quick menu's translation key.
            withTitle: L("menu.settings", "Settings…"),
            action: action,
            keyEquivalent: ","
        )
        settings.target = target
        menu.addItem(.separator())
        menu.addItem(
            withTitle: L("menu.app.hide", "Hide %1$@", name),
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        let others = menu.addItem(
            withTitle: L("menu.app.hide_others", "Hide Others"),
            action: #selector(
                NSApplication.hideOtherApplications(_:)
            ),
            keyEquivalent: "h"
        )
        others.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(
            withTitle: L("menu.app.show_all", "Show All"),
            action: #selector(
                NSApplication.unhideAllApplications(_:)
            ),
            keyEquivalent: ""
        )
        menu.addItem(.separator())
        menu.addItem(
            // Shares the quick menu's Quit key.
            withTitle: L("menu.quit", "Quit KiwiDesk"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        return item
    }

    /// Close answers for whichever window is key (#1533); a
    /// borderless panel earns it by validating `performClose(_:)`
    /// itself, as `JumpPanel` does.
    private static func fileMenu() -> NSMenuItem {
        let item = submenu(L("menu.file.title", "File"))
        item.identifier = fileMenuID
        let menu = item.submenu!
        menu.addItem(
            withTitle: L("menu.file.close", "Close"),
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )
        return item
    }

    private static func editMenu() -> NSMenuItem {
        let item = submenu(L("menu.edit.title", "Edit"))
        item.identifier = editMenuID
        let menu = item.submenu!
        menu.addItem(
            withTitle: L("menu.edit.undo", "Undo"),
            action: Selector(("undo:")),
            keyEquivalent: "z"
        )
        let redo = menu.addItem(
            withTitle: L("menu.edit.redo", "Redo"),
            action: Selector(("redo:")),
            keyEquivalent: "z"
        )
        redo.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(.separator())
        menu.addItem(
            withTitle: L("menu.edit.cut", "Cut"),
            action: #selector(NSText.cut(_:)),
            keyEquivalent: "x"
        )
        menu.addItem(
            withTitle: L("menu.edit.copy", "Copy"),
            action: #selector(NSText.copy(_:)),
            keyEquivalent: "c"
        )
        menu.addItem(
            withTitle: L("menu.edit.paste", "Paste"),
            action: #selector(NSText.paste(_:)),
            keyEquivalent: "v"
        )
        menu.addItem(
            withTitle: L("menu.edit.select_all", "Select All"),
            action: #selector(NSText.selectAll(_:)),
            keyEquivalent: "a"
        )
        return item
    }

    private static func windowMenu() -> NSMenuItem {
        let item = submenu(L("menu.window.title", "Window"))
        let menu = item.submenu!
        menu.addItem(
            withTitle: L("menu.window.minimize", "Minimize"),
            action: #selector(NSWindow.performMiniaturize(_:)),
            keyEquivalent: "m"
        )
        menu.addItem(
            withTitle: L("menu.window.zoom", "Zoom"),
            action: #selector(NSWindow.performZoom(_:)),
            keyEquivalent: ""
        )
        // Not wired to `NSApp.windowsMenu` to prevent overlay panels
        // from being listed.
        return item
    }
}
