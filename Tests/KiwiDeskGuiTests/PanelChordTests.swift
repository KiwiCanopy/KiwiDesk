import AppKit
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A key panel hands its chords to KiwiDesk's File and Edit menus
/// and nothing else (owner ruling 2026-10-13, #1875): the panel
/// takes the keyboard without activating KiwiDesk, so a ⌘Q aimed
/// at the app in front must never reach KiwiDesk's Quit. No menu
/// here is installed, and no event reaches the real App menu.
@Suite("Key panel chords (#1875)")
@MainActor
struct PanelChordTests {
    private final class Recorder: NSObject {
        /// Only its presence matters: a targeted item validates
        /// enabled, so a refusal is the routing's, never a grey.
        @objc func hit(_ sender: NSMenuItem) {}
    }

    private func command(_ key: String) -> NSEvent? {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: .command,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: key,
            charactersIgnoringModifiers: key,
            isARepeat: false,
            keyCode: 0
        )
    }

    private func submenu(
        _ key: String,
        _ recorder: Recorder,
        id: NSUserInterfaceItemIdentifier?
    ) -> NSMenuItem {
        let item = NSMenuItem()
        item.identifier = id
        let menu = NSMenu()
        menu.addItem(
            withTitle: key,
            action: #selector(Recorder.hit(_:)),
            keyEquivalent: key
        ).target = recorder
        item.submenu = menu
        return item
    }

    @Test("only the File and Edit submenus take a panel's chords")
    func onlyFileAndEdit() throws {
        let recorder = Recorder()
        let bar = NSMenu()
        bar.addItem(submenu("q", recorder, id: nil))
        bar.addItem(
            submenu("w", recorder, id: MainMenu.panelChordMenus[0])
        )
        bar.addItem(
            submenu("c", recorder, id: MainMenu.panelChordMenus[1])
        )
        let quit = try #require(command("q"))
        let close = try #require(command("w"))
        let copy = try #require(command("c"))
        #expect(!MainMenu.performPanelChord(quit, in: bar))
        #expect(MainMenu.performPanelChord(close, in: bar))
        #expect(MainMenu.performPanelChord(copy, in: bar))
    }

    /// The flagged submenus are the real File and Edit menus:
    /// Close and the edit chords, never Quit, Hide, Settings or
    /// Minimize.
    @Test("the flags sit on the real File and Edit menus")
    func flagsSitOnFileAndEdit() {
        let bar = MainMenu.make(
            settingsTarget: Recorder(),
            settingsAction: #selector(Recorder.hit(_:))
        )
        let flagged = bar.items.filter {
            $0.identifier.map(MainMenu.panelChordMenus.contains) == true
        }
        #expect(flagged.count == 2)
        let actions = Set(
            flagged.flatMap { $0.submenu?.items ?? [] }
                .compactMap(\.action)
        )
        #expect(actions.contains(#selector(NSWindow.performClose(_:))))
        #expect(actions.contains(#selector(NSText.copy(_:))))
        for barred in [
            #selector(NSApplication.terminate(_:)),
            #selector(NSApplication.hide(_:)),
            #selector(Recorder.hit(_:)),
            #selector(NSWindow.performMiniaturize(_:)),
        ] {
            #expect(!actions.contains(barred))
        }
    }
}
