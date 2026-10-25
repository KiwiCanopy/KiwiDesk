import Foundation
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
                    in: [binding],
                    distinguishingSides: false
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
            resizeStep: 50,
            base: .standard
        )
        for base in ShortcutBase.allCases {
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

/// Each Desktop's name is a whole sentence of its own key, never
/// a frame the number is interpolated into (#2311): Korean's
/// particle agrees with the number — Apple's own labels read
/// `3으로` and `6으로` beside `1로` — so a shared `%1$d` frame
/// is wrong for some Desktops in some locale whatever it says.
/// `.serialized`: `LocalizationManager` is process-wide.
@Suite("Switch to Desktop names (#2311)", .serialized)
@MainActor
struct DesktopSwitchShortcutNameTests {
    private static let localesDirectory = SourceScan.repoRoot(
        from: #filePath
    )
    .appendingPathComponent("Sources/KiwiDeskCore/Resources/Locales")

    @Test("every catalog carries each Desktop's own label")
    func everyCatalogHasEachDesktopsKey() throws {
        let files = try FileManager.default.contentsOfDirectory(
            at: Self.localesDirectory,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "json" }
        #expect(files.count > 1)
        for file in files {
            let catalog = try JSONDecoder().decode(
                [String: String].self,
                from: try Data(contentsOf: file)
            )
            let name = file.lastPathComponent
            for number in 1...9 {
                let key = "system_shortcut.switch_to_desktop_\(number)"
                let value = try #require(
                    catalog[key],
                    "\(name) lacks \(key)"
                )
                #expect(value.contains("\(number)"), "\(name) \(key)")
                #expect(!value.contains("%"), "\(name) \(key)")
            }
            #expect(catalog["system_shortcut.switch_to_desktop"] == nil)
        }
    }

    @Test("Korean takes the particle each number needs")
    func koreanParticleAgrees() {
        LocalizationManager.shared.select("ko")
        defer { LocalizationManager.shared.select(nil) }
        for (index, shortcut)
            in SystemShortcut.switchToDesktop.enumerated()
        {
            let number = index + 1
            let particle = [3, 6].contains(number) ? "으로" : "로"
            #expect(
                shortcut.localizedName.contains("\(number)\(particle)"),
                "\(shortcut.localizedName)"
            )
        }
    }
}
