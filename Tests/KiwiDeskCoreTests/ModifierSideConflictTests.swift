import Testing

@testable import KiwiDeskCore

/// Conflicts read sides as the switch does (#2601): off, two rows
/// a side alone tells apart collapse onto one chord; on, they are
/// two shortcuts; a system shortcut fires from either side
/// whatever the switch says.
@Suite("Modifier sides in conflicts (#2601)")
struct ModifierSideConflictTests {
    private func row(_ id: String, _ combo: String) -> KeyBinding {
        KeyBinding(combo: combo, lua: "print(\"\(id)\")")
    }

    @Test("off: a sided pair is a side collapse; on: no conflict")
    func collapse() {
        let left = row("a", "lcmd+opt+y")
        let right = row("b", "rcmd+opt+y")
        let off = KeybindingConflicts.conflict(for: left, in: [left, right])
        #expect(off?.target == .sideCollapse(right))
        let on = KeybindingConflicts.conflict(
            for: left,
            in: [left, right],
            distinguishingSides: true
        )
        #expect(on == nil)
        let plain = row("c", "cmd+opt+y")
        #expect(
            KeybindingConflicts.conflict(for: plain, in: [plain, right])?
                .target == .sideCollapse(right)
        )
    }

    @Test("the same sided chord twice is a duplicate either way")
    func duplicate() {
        let a = row("a", "rcmd+opt+y")
        let b = row("b", "rcmd+opt+y")
        let on = KeybindingConflicts.conflict(
            for: a,
            in: [a, b],
            distinguishingSides: true
        )
        #expect(on?.target == .otherBinding(b))
    }

    @Test("a sided chord meets the system shortcut on its keys")
    func systemShortcut() throws {
        let spot = row("a", "rcmd+space")
        let conflict = KeybindingConflicts.conflict(
            for: spot,
            in: [spot],
            distinguishingSides: true
        )
        guard case .systemShortcut = try #require(conflict).target else {
            Issue.record("expected the system shortcut")
            return
        }
    }
}

/// The "Shortcuts use" switch leaves a sided row where it is
/// (#2601): Hyper registers bare, so no side could ride onto `✦`.
@Suite("Modifier sides under the shortcut base (#2601)")
struct ModifierSideBaseTests {
    @Test("a sided row stays put; its either-side twin moves")
    func sidedRowStays() throws {
        for text in ["ctrl+opt+rcmd+h", "lctrl+opt+h", "ctrl+ropt+h"] {
            let combo = try #require(KeyCombo.parse(text))
            #expect(ShortcutBase.moved(combo, to: .hyper) == nil, "\(text)")
        }
        let plain = try #require(KeyCombo.parse("ctrl+opt+cmd+h"))
        #expect(ShortcutBase.moved(plain, to: .hyper) != nil)
    }
}
