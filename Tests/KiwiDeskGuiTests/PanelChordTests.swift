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

    /// What a panel's chord may trigger is an allow-list of
    /// ACTIONS: a row later added to File or Edit reds here until
    /// it is ruled safe to fire while another app is in front.
    @Test("a panel's chords reach only the ruled actions")
    func onlyRuledActions() {
        let bar = MainMenu.make(
            settingsTarget: Recorder(),
            settingsAction: #selector(Recorder.hit(_:))
        )
        let flagged = bar.items.filter {
            $0.identifier.map(MainMenu.panelChordMenus.contains) == true
        }
        let actions = flagged.flatMap { $0.submenu?.items ?? [] }
            .compactMap(\.action)
        let ruled: Set<Selector> = [
            #selector(NSWindow.performClose(_:)),
            Selector(("undo:")),
            Selector(("redo:")),
            #selector(NSText.cut(_:)),
            #selector(NSText.copy(_:)),
            #selector(NSText.paste(_:)),
            #selector(NSText.selectAll(_:)),
        ]
        #expect(Set(actions) == ruled)
        #expect(actions.count == ruled.count)
    }

    /// No key panel forwards to the whole menu: the one forward
    /// lives in `MainMenu`, and every window that makes itself
    /// key-capable (`canBecomeKey` → true, the key panels' shape)
    /// takes it. Trade: a key window spelled another way is
    /// outside the second needle.
    @Test("the whole-menu forward has no home outside MainMenu")
    func noWholeMenuForward() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        var forwards: Set<String> = []
        var panels: Set<String> = []
        var scanned = 0
        for file in try SourceScan.swiftSources(under: root) {
            scanned += 1
            let source = try SourceScan.strippedSource(at: file)
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "\n", with: "")
            if source.range(
                of: #"mainMenu\??\.performKeyEquivalent"#,
                options: .regularExpression
            ) != nil {
                forwards.insert(file.lastPathComponent)
            }
            if source.contains("canBecomeKey:Bool{true}") {
                panels.insert(file.lastPathComponent)
                #expect(
                    source.contains("MainMenu.performPanelChord(event)"),
                    "\(file.lastPathComponent)"
                )
            }
        }
        #expect(scanned > 100)
        #expect(forwards.isEmpty)
        #expect(!panels.isEmpty)
    }

    /// A key-capable window in Core cannot reach
    /// `MainMenu.performPanelChord`, so it takes no chord and hands
    /// none on: it swallows them all (#2563, bars.md). Matches a
    /// `canBecomeKey` override answering anything but `false`.
    /// Trade: a key window spelled another way is outside it.
    @Test("a key-capable Core panel swallows every chord")
    func coreKeyPanelsSwallow() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        var keyable: Set<String> = []
        var scanned = 0
        for file in try SourceScan.swiftSources(under: root) {
            scanned += 1
            let source = try SourceScan.strippedSource(at: file)
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "\n", with: "")
            let needle = "overridevarcanBecomeKey:Bool{"
            guard let hit = source.range(of: needle),
                !source[hit.upperBound...].hasPrefix("false}")
            else { continue }
            keyable.insert(file.lastPathComponent)
            #expect(
                source.contains(
                    "overridefuncperformKeyEquivalent(withevent:NSEvent)"
                        + "->Bool{"
                ),
                "\(file.lastPathComponent)"
            )
        }
        #expect(scanned > 300)
        #expect(keyable.contains("BarPeekWindow.swift"))
    }
}
