import AppKit
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The panel reads its keys ahead of the search field (#1875) —
/// save while an input method composes, when Return commits the
/// composition, Esc cancels it and the arrows pick a candidate.
@Suite("Jump to window panel events")
@MainActor
struct JumpPanelEventTests {
    private func keyDown(
        _ code: UInt16,
        _ characters: String,
        repeated: Bool = false
    ) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: repeated,
            keyCode: code
        )!
    }

    private func panel() -> (JumpPanel, NSTextView) {
        let panel = JumpPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: true
        )
        let field = NSTextView(
            frame: NSRect(x: 0, y: 0, width: 200, height: 40)
        )
        panel.contentView?.addSubview(field)
        panel.makeFirstResponder(field)
        return (panel, field)
    }

    @Test("Return and the arrows reach the panel, not the field")
    func panelReadsItsKeys() {
        let (panel, _) = panel()
        var keys: [JumpKey] = []
        panel.onKey = { key, _ in keys.append(key) }
        panel.sendEvent(keyDown(36, "\r"))
        panel.sendEvent(keyDown(125, ""))
        #expect(keys == [.pick(moveHere: false), .step(1)])
    }

    @Test("a held key reaches the model as held (#2897)")
    func repeatIsCarried() {
        let (panel, _) = panel()
        var held: [Bool] = []
        panel.onKey = { _, repeated in held.append(repeated) }
        panel.sendEvent(keyDown(125, ""))
        panel.sendEvent(keyDown(125, "", repeated: true))
        #expect(held == [false, true])
    }

    @Test("a held ⌘ arrow reaches the model as held (#2897)")
    func commandRepeatIsCarried() {
        let (panel, _) = panel()
        panel.keyedForTesting = true
        var held: [Bool] = []
        panel.onKey = { _, repeated in held.append(repeated) }
        for repeated in [false, true] {
            let down = NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: .command,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "",
                charactersIgnoringModifiers: "",
                isARepeat: repeated,
                keyCode: 125
            )!
            #expect(panel.performKeyEquivalent(with: down))
        }
        #expect(held == [false, true])
    }

    /// The controller is the one wiring from panel to model; a
    /// panel test replaces `onKey`, so only this sees it (#2897).
    @Test("the controller hands the held flag to the model")
    func controllerPassesTheRepeat() throws {
        let body = try SourceScan.functionBody(
            of: "wire",
            in: "JumpPanelController.swift",
            under: "Jump",
            root: "Sources/KiwiDesk"
        )
        #expect(body.contains("handle($0, repeated: $1)"))
    }

    @Test("while an input method composes, every key is the field's")
    func compositionKeepsItsKeys() {
        let (panel, field) = panel()
        var keys: [JumpKey] = []
        panel.onKey = { key, _ in keys.append(key) }
        field.setMarkedText(
            "にほ",
            selectedRange: NSRange(location: 2, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: 0)
        )
        #expect(panel.composing)
        panel.sendEvent(keyDown(36, "\r"))
        #expect(keys.isEmpty)
    }

    @Test("modifier changes reach the panel")
    func modifiersReachThePanel() {
        let (panel, _) = panel()
        var flags: [NSEvent.ModifierFlags] = []
        panel.onModifiers = { flags.append($0) }
        let event = NSEvent.keyEvent(
            with: .flagsChanged,
            location: .zero,
            modifierFlags: .command,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: 55
        )!
        panel.sendEvent(event)
        #expect(flags.map { $0.contains(.command) } == [true])
    }

    /// AppKit offers a ⌘ key to the menus before `keyDown`, and
    /// KiwiDesk's "Settings… ⌘," took ⌘, from the Shortcuts and
    /// Layouts sides (#2246): the panel claims its own chord there.
    @Test("⌘, reaches a side before the app menu's Settings…")
    func commandCommaIsTheSides() {
        let (panel, _) = panel()
        panel.keyedForTesting = true
        var keys: [JumpKey] = []
        panel.onKey = { key, _ in keys.append(key) }
        let comma = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: .command,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: ",",
            charactersIgnoringModifiers: ",",
            isARepeat: false,
            keyCode: 43
        )!
        for scope in [JumpScope.shortcuts, .view] {
            panel.scope = { scope }
            #expect(panel.performKeyEquivalent(with: comma))
        }
        #expect(keys == [.settings, .settings])
        // Windows answers no ⌘, of its own.
        panel.scope = { .windows }
        _ = panel.performKeyEquivalent(with: comma)
        #expect(keys.count == 2)
    }

    private func chord(
        _ key: String,
        _ code: UInt16,
        _ flags: NSEvent.ModifierFlags = .command
    ) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: flags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: key,
            charactersIgnoringModifiers: key,
            isARepeat: false,
            keyCode: code
        )!
    }

    /// ⌘Q, ⌘H and ⌘, aimed at the app in front never reach
    /// KiwiDesk's own Quit, Hide or Settings… while the panel holds
    /// the keyboard (owner ruling 2026-10-13): the real menu's
    /// chords are swallowed, the File and Edit ones handed on.
    @Test("KiwiDesk's other menu chords are swallowed, not performed")
    func appMenuChordsAreSwallowed() {
        let bar = MainMenu.make(
            settingsTarget: NSObject(),
            settingsAction: #selector(NSObject.description)
        )
        #expect(MainMenu.holdsChord(chord("q", 12), in: bar))
        #expect(MainMenu.holdsChord(chord("h", 4), in: bar))
        #expect(MainMenu.holdsChord(chord(",", 43), in: bar))
        #expect(!MainMenu.holdsChord(chord("k", 40), in: bar))
        #expect(
            !MainMenu.holdsChord(chord("q", 12, [.command, .option]), in: bar)
        )
        let (panel, _) = panel()
        panel.keyedForTesting = true
        panel.scope = { .windows }
        var keys: [JumpKey] = []
        panel.onKey = { key, _ in keys.append(key) }
        let old = NSApplication.shared.mainMenu
        NSApplication.shared.mainMenu = bar
        defer { NSApplication.shared.mainMenu = old }
        #expect(panel.performKeyEquivalent(with: chord("q", 12)))
        #expect(panel.performKeyEquivalent(with: chord("h", 4)))
        #expect(keys.isEmpty)
        // Not key, the panel claims nothing.
        panel.keyedForTesting = false
        panel.scope = { .shortcuts }
        _ = panel.performKeyEquivalent(with: chord(",", 43))
        #expect(keys.isEmpty)
    }

    /// The panel's own ⌘ chords never shadow a File or Edit chord
    /// the field relies on (⌘W, ⌘A, ⌘C, ⌘V, ⌘X, ⌘Z): every
    /// handed-on item is asked of `JumpKey` on every side, so a new panel
    /// chord is checked without joining a list here.
    @Test("the panel's chords and the handed-on menus do not overlap")
    func panelChordsLeaveEditAlone() {
        let bar = MainMenu.make(
            settingsTarget: NSObject(),
            settingsAction: #selector(NSObject.description)
        )
        let items = bar.items
            .filter {
                $0.identifier.map(MainMenu.panelChordMenus.contains)
                    == true
            }
            .flatMap { $0.submenu?.items ?? [] }
            .filter { !$0.keyEquivalent.isEmpty }
        #expect(items.count >= 6)
        for item in items {
            let key = item.keyEquivalent.lowercased()
            guard let code = Self.ansiCodes[key] else {
                Issue.record("no key code for ⌘\(key)")
                continue
            }
            for scope in JumpScope.allCases {
                #expect(
                    JumpKey.of(
                        keyCode: code,
                        modifiers: item.keyEquivalentModifierMask,
                        scope: scope,
                        naming: false
                    ) == nil,
                    "the panel claims \(item.title)'s chord on \(scope)"
                )
            }
        }
    }

    /// ANSI key codes of the characters a menu key equivalent uses.
    private static let ansiCodes: [String: UInt16] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6,
        "x": 7, "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14,
        "r": 15, "y": 16, "t": 17, "1": 18, "2": 19, "3": 20,
        "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26,
        "-": 27, "8": 28, "0": 29, "o": 31, "u": 32, "i": 34,
        "p": 35, "l": 37, "j": 38, "k": 40, ",": 43, "/": 44,
        "n": 45, "m": 46, ".": 47,
    ]
}
