import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// One rule for a row on a macOS shortcut, whichever door hears its
/// press (#3311): `SystemShortcut.losesToKiwiDesk(on:)`, read by a
/// row's conflict through the path Core stamps on it and by a step
/// key through `ConflictSeverity.ofStep`.
struct PressPathSeverityTests {
    private func row(_ combo: String) -> KeyBinding {
        KeyBinding(
            combo: combo,
            lua: "KiwiDesk.focus(\"left\")",
            kind: .navigation,
            label: "Focus window left"
        )
    }

    private func conflict(
        _ binding: KeyBinding,
        sides: Bool = false
    ) throws -> Conflict {
        try #require(
            KeybindingConflicts.conflict(
                for: binding,
                in: [binding],
                distinguishingSides: sides
            )
        )
    }

    /// Measured 2026-11-14 (#3311), macOS 27.2: with a leader on
    /// each chord, a posted press opened the sequence and macOS did
    /// nothing, where with nothing bound it opened Spotlight, Finder
    /// search, Mission Control, App windows, the screenshot tools,
    /// switched a Space, ran ⌘Tab and toggled Dock hiding. A posted
    /// ⌥⌘Esc opened no Force Quit, so that chord stays dead.
    @Test("a leader takes every measured macOS chord, save ⌥⌘Esc")
    func leaderTakesTheChord() throws {
        for (combo, shortcut) in [
            ("command+space", SystemShortcut.spotlight),
            ("command+tab", .appSwitcher),
            ("control+up", .missionControl),
            ("option+command+d", .dockHiding),
        ] {
            let leader = KeyBinding(combo: combo, kind: .sequence)
            #expect(
                ConflictSeverity.of(try conflict(leader), disabled: [])
                    == .winsFromMacOS(shortcut)
            )
            let carbon = try conflict(row(combo))
            #expect(ConflictSeverity.of(carbon, disabled: []).isDead)
        }
        let forceQuit = KeyBinding(
            combo: "command+option+escape",
            kind: .sequence
        )
        #expect(
            ConflictSeverity.of(try conflict(forceQuit), disabled: [])
                == .dead(.forceQuit)
        )
    }

    /// The #3311 defect: a leader and a step key on one chord are
    /// both decided by the keyboard tap, so they read alike — each
    /// macOS shortcut an open sequence passes, both rows win it or
    /// both are dead.
    @Test("a leader and a step key on one chord read alike")
    func leaderAndStepAgree() throws {
        let passed = SystemShortcuts.map.filter {
            $0.value.sequenceTier != .swallowed
        }
        #expect(!passed.isEmpty)
        for (combo, shortcut) in passed {
            let text = try #require(combo.comboString())
            let leader = KeyBinding(combo: text, kind: .sequence)
            let asLeader = ConflictSeverity.of(
                try conflict(leader),
                disabled: []
            )
            let asStep = ConflictSeverity.ofStep(on: shortcut)
            #expect(asLeader.isDead == asStep.isDead, "\(text)")
            #expect(
                (asLeader == .winsFromMacOS(shortcut))
                    == (asStep == .takesFromMacOS(shortcut)),
                "\(text)"
            )
        }
        #expect(ConflictSeverity.ofStep(on: .forceQuit) == .dead(.forceQuit))
        #expect(
            ConflictSeverity.ofStep(on: .spotlight)
                == .takesFromMacOS(.spotlight)
        )
    }

    /// A sided row the keyboard tap answers is decided like a
    /// leader; with sides not told apart it is a Carbon hotkey.
    @Test("a sided row reads by the path that answers it")
    func sidedRowReadsItsPath() throws {
        let sided = row("rcmd+space")
        for (sides, dead) in [(true, false), (false, true)] {
            let found = try conflict(sided, sides: sides)
            #expect(
                ConflictSeverity.of(found, disabled: []).isDead == dead
            )
        }
    }
}
