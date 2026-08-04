import AppKit
import KiwiDeskCore

/// Builds KiwiDesk's application menu bar.
///
/// A bare SwiftPM executable ships no `MainMenu.nib`, so
/// `NSApp.mainMenu` is nil until we install one.
///
/// **It is still needed even though the app never leaves
/// `.accessory` and so never displays a menu bar.** AppKit
/// dispatches menu key equivalents through `NSApp.mainMenu` for
/// the key window whatever the activation policy, so this is what
/// gives the Settings text fields their standard Edit shortcuts
/// (Cut/Copy/Paste/Undo) — without it they have none. It
/// originally also fixed an auto-hide menu bar with nothing to
/// reveal on a top-edge hover (#329), which the permanent
/// `.accessory` policy now prevents outright.
///
/// Titles route through `L(_:_:)` like every GUI string (#9);
/// the items use AppKit's standard first-responder selectors so
/// the responder chain services them with no extra wiring.
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
        bar.addItem(editMenu())
        bar.addItem(windowMenu())
        return bar
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
            // Shares the quick menu's key — one "Settings…"
            // translation unit, both routes to the dashboard.
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

    private static func editMenu() -> NSMenuItem {
        let item = submenu(L("menu.edit.title", "Edit"))
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
        // Deliberately NOT wired to `NSApp.windowsMenu`: that
        // would auto-append every eligible window, and KiwiDesk's
        // borderless overlay panels (border rings, App Bar, drag
        // ghost) are only kept out by an unenforced invariant. A
        // 1–2 window settings app gains nothing from the window
        // list; Minimize/Zoom still reach the key window through
        // the responder chain without it.
        return item
    }
}
