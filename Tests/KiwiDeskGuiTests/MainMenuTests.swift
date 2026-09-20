import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The main menu's Close item (#1533).
///
/// KiwiDesk is `.accessory`, so its main menu exists only to route
/// key equivalents to the key window — and until #1533 it carried
/// no File menu, so nothing answered ⌘W and the Settings window
/// could not be closed from the keyboard. The census clause pins
/// the standard item; the panel clause pins the one window that
/// cannot take it for free, since AppKit greys Close for a
/// window without `.closable`.
///
/// `@MainActor` for `NSMenu` and `NSPanel`; the panel is built
/// deferred and never ordered in, so no window reaches the
/// machine.
@Suite("Main menu Close item (#1533)")
@MainActor
struct MainMenuTests {
    private final class Target: NSObject {
        @objc func noop(_ sender: Any?) {}
    }

    private func makeBar() -> NSMenu {
        MainMenu.make(
            settingsTarget: Target(),
            settingsAction: #selector(Target.noop(_:))
        )
    }

    /// Every item of every submenu, depth first.
    private func allItems(of menu: NSMenu) -> [NSMenuItem] {
        menu.items.flatMap { item -> [NSMenuItem] in
            guard let submenu = item.submenu else { return [item] }
            return [item] + allItems(of: submenu)
        }
    }

    private var closeSelector: Selector {
        #selector(NSWindow.performClose(_:))
    }

    @Test("the File menu carries the standard Close item on ⌘W")
    func closeItemIsStandard() {
        let bar = makeBar()
        let closes = allItems(of: bar).filter {
            $0.action == closeSelector
        }
        #expect(closes.count == 1)
        guard let close = closes.first else { return }
        #expect(close.keyEquivalent == "w")
        #expect(close.keyEquivalentModifierMask == [.command])
        // Nil target: the responder chain answers, so the item
        // reaches whichever window is key.
        #expect(close.target == nil)
        #expect(close.menu?.supermenu === bar)
        #expect(close.menu !== bar.items.first?.submenu)
    }

    @Test("no other item claims ⌘W")
    func closeIsTheOnlyCommandW() {
        let bar = makeBar()
        let commandW = allItems(of: bar).filter {
            $0.keyEquivalent == "w"
                && $0.keyEquivalentModifierMask == [.command]
        }
        #expect(commandW.map(\.action) == [closeSelector])
    }

    /// A borderless window fails AppKit's own Close validation,
    /// so the Shortcuts panel validates the item itself and
    /// answers it with the keyboard-commanded cancel. The panel
    /// is the controller's own build, so a change to its class
    /// or style mask is what this clause reads.
    @Test("the borderless Shortcuts panel validates and answers Close")
    func shortcutsPanelHonoursClose() {
        let controller = ShortcutsPanelController(
            core: makeTestCore(),
            onEdit: {}
        )
        let panel = controller.makePanel()
        #expect(!panel.styleMask.contains(.closable))
        var cancelled = 0
        panel.onCancel = { cancelled += 1 }
        let close = NSMenuItem(
            title: "Close",
            action: closeSelector,
            keyEquivalent: "w"
        )
        #expect(panel.validateUserInterfaceItem(close))
        panel.performClose(nil)
        #expect(cancelled == 1)
        // The override is narrow: a verb the panel cannot perform
        // still takes AppKit's verdict.
        let minimize = NSMenuItem(
            title: "Minimize",
            action: #selector(NSWindow.performMiniaturize(_:)),
            keyEquivalent: "m"
        )
        #expect(!panel.validateUserInterfaceItem(minimize))
    }
}
