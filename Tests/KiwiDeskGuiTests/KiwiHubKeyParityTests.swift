import AppKit
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// `kiwihub.set_key`'s refusals are Core's, the keys they protect
/// the panel's (#2600): every chord KiwiHub answers itself, and
/// every File or Edit chord it hands on, is refused as an
/// alternative, and the panel KiwiDesk builds reads what the verb
/// set.
@Suite("KiwiHub key parity (#2600)")
@MainActor
struct KiwiHubKeyParityTests {
    private static let modifierSets: [NSEvent.ModifierFlags] = {
        let all: [NSEvent.ModifierFlags] = [
            .control, .option, .shift, .command,
        ]
        return (0..<16).map { bits in
            all.enumerated().reduce(into: []) { flags, entry in
                if bits & (1 << entry.offset) != 0 {
                    flags.insert(entry.element)
                }
            }
        }
    }()

    private static func combo(
        _ code: UInt16,
        _ flags: NSEvent.ModifierFlags
    ) -> KeyCombo {
        var modifiers: HotkeyModifiers = []
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.command) { modifiers.insert(.command) }
        return KeyCombo(keyCode: UInt32(code), modifiers: modifiers)
    }

    private static func refused(_ combo: KeyCombo) -> Bool {
        KiwiHubKeyRefusal.of(combo, as: .down, in: KiwiHubKeys()) != nil
    }

    @Test("every chord the panel answers is refused")
    func panelKeysAreRefused() {
        var answered = 0
        for scope in JumpScope.allCases {
            for code in UInt16(0)..<128 {
                for flags in Self.modifierSets {
                    guard
                        JumpKey.of(
                            keyCode: code,
                            modifiers: flags,
                            scope: scope,
                            naming: false
                        ) != nil
                    else { continue }
                    answered += 1
                    let combo = Self.combo(code, flags)
                    #expect(
                        Self.refused(combo),
                        "\(scope) \(code) \(flags.rawValue)"
                    )
                }
            }
        }
        #expect(answered > 100)
    }

    @Test("every File and Edit chord the panel hands on is refused")
    func menuChordsAreRefused() throws {
        let bar = MainMenu.make(
            settingsTarget: NSObject(),
            settingsAction: #selector(NSObject.description)
        )
        var chords = 0
        for item in bar.items {
            guard let id = item.identifier,
                MainMenu.panelChordMenus.contains(id),
                let menu = item.submenu
            else { continue }
            for row in menu.items where !row.keyEquivalent.isEmpty {
                let code = try #require(
                    KeyCombo.keyCodes[row.keyEquivalent.lowercased()]
                )
                let combo = Self.combo(
                    UInt16(code),
                    row.keyEquivalentModifierMask
                )
                chords += 1
                #expect(Self.refused(combo), "\(row.keyEquivalent)")
            }
        }
        #expect(chords >= 7)
    }

    @Test("the panel KiwiDesk builds reads the verb's keys")
    func panelReadsTheVerb() throws {
        let core = makeTestCore()
        let panel = JumpPanelController(core: core).makePanel()
        var keys: [JumpKey] = []
        panel.onKey = { keys.append($0) }
        #expect(
            core.execute(
                "kiwihub.set_key",
                args: [.string("down"), .string("ctrl+n")]
            ).isSuccess
        )
        let event = try #require(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: .control,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "\u{0E}",
                charactersIgnoringModifiers: "n",
                isARepeat: false,
                keyCode: 45
            )
        )
        panel.sendEvent(event)
        #expect(keys == [.step(1)])
    }

    @Test("a ⌘ alternative reaches the panel as a key equivalent")
    func commandAlternativeIsAKeyEquivalent() throws {
        let core = makeTestCore()
        let panel = JumpPanelController(core: core).makePanel()
        panel.keyedForTesting = true
        var keys: [JumpKey] = []
        panel.onKey = { keys.append($0) }
        #expect(
            core.execute(
                "kiwihub.set_key",
                args: [.string("down"), .string("cmd+j")]
            ).isSuccess
        )
        let event = try #require(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: .command,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "j",
                charactersIgnoringModifiers: "j",
                isARepeat: false,
                keyCode: 38
            )
        )
        #expect(panel.performKeyEquivalent(with: event))
        #expect(keys == [.step(1)])
    }
}
