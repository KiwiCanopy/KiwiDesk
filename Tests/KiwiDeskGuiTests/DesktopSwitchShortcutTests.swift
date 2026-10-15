import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Mission Control ▸ Switch to Desktop N (#2311): ⌃1…⌃9 are
/// reserved chords, warned about only while macOS has them ON.
/// Read from `com.apple.symbolichotkeys` on macOS 27.0.1: ids
/// 118…126, control mask, the digit keys' virtual keycodes.
struct DesktopSwitchShortcutTests {
    /// The measured keycode of each digit 1…9, in Desktop order
    /// — the plist's own parameters, not `KeyCombo`'s table.
    private static let keycodes: [UInt32] = [
        18, 19, 20, 21, 23, 22, 26, 28, 25,
    ]

    @Test("⌃1…⌃9 conflict with Switch to Desktop 1…9")
    func controlDigitsAreReserved() throws {
        for number in 1...9 {
            let combo = try #require(
                KeyCombo.parse("control+\(number)")
            )
            #expect(combo.keyCode == Self.keycodes[number - 1])
            #expect(combo.modifiers == [.control])
            let shortcut = try #require(SystemShortcuts.map[combo])
            #expect(shortcut.desktopNumber == number)
            let binding = KeyBinding(
                combo: "control+\(number)",
                lua: "KiwiDesk.focus(\"left\")"
            )
            let conflict = try #require(
                KeybindingConflicts.conflict(
                    for: binding,
                    in: [binding]
                )
            )
            #expect(conflict.target == .systemShortcut(shortcut))
            // Off by default → a note, not a warning; on → dead.
            #expect(
                ConflictSeverity.of(
                    conflict,
                    disabled: SystemShortcutEnablement.disabled(
                        reading: { _ in nil }
                    )
                ) == .dormant(shortcut)
            )
            #expect(
                ConflictSeverity.of(conflict, disabled: [])
                    == .dead(shortcut)
            )
        }
    }

    @Test("Desktop N reads symbolic hotkey 117 + N, shipped off")
    func enablementIdsAreMeasured() throws {
        #expect(SystemShortcut.switchToDesktop.count == 9)
        for (index, shortcut)
            in SystemShortcut.switchToDesktop.enumerated()
        {
            let entry = try #require(shortcut.symbolicHotkey)
            #expect(entry.id == 118 + index)
            #expect(!entry.shipsEnabled)
            #expect(!shortcut.isUniversalAccelerator)
            // The plist's own entry switches it on.
            let on = SystemShortcutEnablement.disabled(
                reading: { $0 == entry.id ? true : nil }
            )
            #expect(!on.contains(shortcut))
        }
    }

    /// The seed binds digits on `⌃⌥`, `⌃⌥⇧`, `⌃⌥⌘`, `⌥⌘`
    /// and the Desktop tier — never bare `⌃` — so the new
    /// register entries change no seeded row's tier.
    @Test("no seeded chord is a bare ⌃ + digit")
    func seedKeepsItsTiers() throws {
        var seeded = DefaultKeybindings.bindings(
            spaces: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"],
            resizeStep: 50
        )
        for base in DesktopShortcutBase.allCases {
            seeded += (1...10).compactMap {
                DefaultKeybindings.desktopRow($0, base: base)
            }
        }
        for generation in 1...DefaultKeybindings.newestGeneration {
            seeded += DefaultKeybindings.rows(ofGeneration: generation)
        }
        #expect(seeded.count > 40)
        let bareControlDigits = Set(
            (0...9).compactMap { KeyCombo.parse("control+\($0)") }
        )
        #expect(bareControlDigits.count == 10)
        for row in seeded where !row.combo.isEmpty {
            let combo = try #require(KeyCombo.parse(row.combo))
            #expect(
                !bareControlDigits.contains(combo.registered),
                "\(row.combo) is a bare ⌃ + digit"
            )
            let reserved = SystemShortcuts.map[combo.registered]
            #expect(
                reserved?.desktopNumber == nil,
                "\(row.combo) meets \(reserved as Any)"
            )
        }
    }
}
