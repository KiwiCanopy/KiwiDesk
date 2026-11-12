import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A modifier tap as the GUI draws and says it (#1872 ▸ Ruling):
/// `⌘⌘`, `Right ⌥⌥`, `Right ⌘`, spoken "Command, press twice".
@Suite("Modifier tap drawing and words (#1872)")
@MainActor
struct ModifierTapWordsTests {
    private func combo(_ text: String) throws -> KeyCombo {
        try #require(KeyCombo.parse(text))
    }

    @Test("a tap draws as its glyph per press, the side said once")
    func drawn() throws {
        LocalizationManager.shared.select("en")
        let draw = { (text: String) throws -> String in
            ChordGlyphs.render(try self.combo(text), layoutChar: { _ in nil })
        }
        #expect(try draw("cmd+cmd") == "⌘⌘")
        #expect(try draw("ropt+ropt") == "Right ⌥⌥")
        #expect(try draw("rcmd") == "Right ⌘")
    }

    @Test("a tap says its modifier and how many presses")
    func spoken() throws {
        LocalizationManager.shared.select("en")
        #expect(
            ModifierTapWords.spoken(try combo("cmd+cmd"))
                == "Command, press twice"
        )
        #expect(
            ModifierTapWords.spoken(try combo("ropt+ropt"))
                == "Right Option, press twice"
        )
        #expect(
            ModifierTapWords.spoken(try combo("rcmd"))
                == "Right Command, press once"
        )
        #expect(ModifierTapWords.spoken(try combo("cmd+h")) == nil)
    }

    @Test("the wait names the double tap one more press records")
    func tapAgain() throws {
        LocalizationManager.shared.select("en")
        let single = try combo("rcmd")
        #expect(
            ModifierTapWords.tapAgain(single, sidesKept: false)
                == "Tap again for ⌘⌘"
        )
        #expect(
            ModifierTapWords.tapAgain(single, sidesKept: true)
                == "Tap again for Right ⌘⌘"
        )
    }

    /// A single tap's lasting caption (#3257), drawn and spoken.
    @Test("a recorded single tap says how a double tap is made")
    func tapOnceRecorded() throws {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        let words = try #require(
            ModifierTapWords.tapOnceRecorded(
                try combo("rcmd"),
                sidesKept: false
            )
        )
        #expect(
            words.drawn
                == "Right ⌘ recorded. For ⌘⌘, tap twice within a moment."
        )
        #expect(
            words.spoken
                == "Recorded: Right Command, pressed once. For a double "
                + "press, press Command twice within a moment."
        )
        #expect(
            ModifierTapWords.tapOnceRecorded(
                try combo("rcmd"),
                sidesKept: true
            )?.drawn.contains("Right ⌘⌘") == true
        )
        for other in ["cmd+cmd", "cmd+h"] {
            #expect(
                ModifierTapWords.tapOnceRecorded(
                    try combo(other),
                    sidesKept: false
                ) == nil
            )
        }
    }

    /// Shown only for a recorded single tap, never on a chord, a
    /// double tap or a row that held a single tap (#3257).
    @Test("only a single tap leaves the caption")
    func tapOnceNoteVerdicts() throws {
        let tap = try combo("rcmd")
        let note = KeyRecorderField.tapOnceNote(for:held:)
        #expect(note("rcmd", "") == tap)
        #expect(note("rcmd", "cmd+h") == tap)
        #expect(note("rcmd+rcmd", "") == nil)
        #expect(note("rcmd+h", "") == nil)
        #expect(note("rcmd", "lopt") == nil)
    }

    /// The field's own commit keeps the note; any other value — a
    /// steal, a reload, a Sides pick, a clear — ends it (#3257).
    @Test("only the field's own commit keeps the caption")
    func tapOnceNoteKeeps() throws {
        let tap = try combo("rcmd")
        let keeps = KeyRecorderField.keepsTapOnceNote
        #expect(keeps(tap, "rcmd"))
        #expect(!keeps(tap, "cmd"))
        #expect(!keeps(tap, "rcmd+h"))
        #expect(!keeps(tap, ""))
        #expect(keeps(nil, "rcmd"))
    }

    /// Every edit the ruling names ends the note; focus does not.
    @Test("the caption lasts until the field's next edit")
    func tapOnceNoteWiring() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Keybindings/"
                    + "Recorder/KeyRecorderField.swift"
            )
        let field = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        ).filter { !$0.isWhitespace }
        for needle in [
            // A new recording, Clear, a generation change, leaving.
            "privatefuncstart(){tapOnceNote=nil",
            "Button{tapOnceNote=nilonClear()}",
            ".onChange(of:coordinator.generation){_,_intapOnceNote=nil",
            ".onDisappear{stop()tapOnceNote=nil}",
            // An outside change of the value.
            ".onChange(of:combo){_,nowinkeepTapOnceNote(now)}",
            // Set only where the commit recorded.
            // From the recorded combo alone, set only where the
            // commit recorded: the recorder clears the pending tap
            // before its outcome arrives.
            "letnote=tapOnceNote(for:recorded)"
                + "ifcommit(recorded){tapOnceNote=note}",
            "tapOnceCaption",
        ] {
            #expect(field.contains(needle), "\(needle)")
        }
        // `finish` reads no pending tap: it is nil by then (#3257).
        let finishStart = try #require(
            field.range(of: "privatefuncfinish(")
        )
        let rest = field[finishStart.upperBound...]
        let finish = rest.prefix(
            upTo: rest.range(of: "privatefunc")?.lowerBound ?? rest.endIndex
        )
        #expect(!finish.contains("=pendingTap"))
        #expect(!finish.contains("pendingTap)"))
        // Focus leaving runs `stop`, which keeps the note.
        let stop = try #require(
            field.range(of: "privatefuncstop(){")
        )
        let tail = field[stop.upperBound...].prefix(80)
        #expect(!tail.contains("tapOnceNote"))
    }

    @Test("every chord surface speaks a drawn double tap in words")
    func sharedDoorSpeaksDoubles() {
        LocalizationManager.shared.select("en")
        #expect(SidedChordWords.label("⌘⌘") == "Command, press twice")
        #expect(
            SidedChordWords.label("Right ⌥⌥")
                == "Right Option, press twice"
        )
        // A single sided glyph is also a modifier-layer chip, so
        // the shared door leaves it as a chord.
        let chip = SidedChordWords.spoken("Right ⌘")
        #expect(chip?.contains("press") == false)
        #expect(SidedChordWords.spoken("⌘⌥") == nil)
    }

    @Test("a tap row carries no either-side hint, a sided chord does")
    func noEitherSideHintOnTaps() {
        LocalizationManager.shared.select("en")
        let hint = { (combo: String) in
            KeyRecorderField.rowHint(
                combo: combo,
                sidesOn: false,
                recording: false,
                hyperDormant: false
            )
        }
        #expect(hint("rcmd") == nil)
        #expect(hint("ropt+ropt") == nil)
        #expect(hint("rcmd+h") != nil)
    }

    @Test("the keyboard board leaves taps out")
    func boardSkipsTaps() {
        let layer = KeyLayer(
            name: "default",
            bindings: [
                KeyBinding(combo: "cmd+cmd", lua: "print(1)"),
                KeyBinding(combo: "cmd+h", lua: "print(2)"),
            ]
        )
        #expect(
            KeyboardCensus.combos(in: [layer]) == [KeyCombo.parse("cmd+h")]
        )
    }
}
