import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The quiet caption under an either-side row a sided row narrows,
/// and the dead row's reading when both sides are taken (#3256). The
/// caption and the reading come from Core's one `SideReach`.
/// Main-actor spend: string building and two small source reads.
@Suite("Side narrowing caption (#3256)")
@MainActor
struct SideNarrowingCaptionTests {
    private func row(_ id: String, _ combo: String) -> KeyBinding {
        KeyBinding(combo: combo, lua: "print(\"\(id)\")", label: id)
    }

    @Test("the caption says which side runs it and who has the other")
    func captionWords() throws {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        let either = row("Either", "cmd+cmd")
        let left = row("Left row", "lcmd+lcmd")
        let narrowing = try #require(
            SideNarrowing.of(
                either,
                in: [either, left],
                config: GuiConfig(),
                sides: true
            )
        )
        #expect(narrowing.taken.by == left)
        let words = try #require(
            SideReachWords.caption(
                runs: narrowing.runs,
                taken: narrowing.taken,
                holder: "Show KiwiHub"
            )
        )
        #expect(
            words.drawn
                == "Only Right ⌘⌘ runs this. Left ⌘⌘ runs "
                + "\u{201C}Show KiwiHub\u{201D}."
        )
        #expect(
            words.spoken
                == "Runs from: Right Command, press twice. "
                + "\u{201C}Show KiwiHub\u{201D} takes: Left Command, "
                + "press twice."
        )
        // The sided row, and a row no side is taken from, draw none.
        for (binding, rows) in [
            (left, [either, left]), (either, [either]),
        ] {
            #expect(
                SideNarrowing.of(
                    binding,
                    in: rows,
                    config: GuiConfig(),
                    sides: true
                ) == nil
            )
        }
    }

    @Test("both sides taken is a dead row, never a caption")
    func bothSidesTakenIsDead() throws {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        let either = row("Either", "cmd+cmd")
        let left = row("Left row", "lcmd+lcmd")
        let right = row("Right row", "rcmd+rcmd")
        let rows = [either, left, right]
        #expect(
            SideNarrowing.of(
                either,
                in: rows,
                config: GuiConfig(),
                sides: true
            ) == nil
        )
        let reading = try #require(
            ConflictText.reading(
                for: either,
                in: rows,
                config: GuiConfig(),
                disabled: [],
                sides: true
            )
        )
        #expect(reading.severity == .sidesTaken([left, right]))
        #expect(reading.severity.isDead)
        #expect(reading.severity.otherBinding == left)
        #expect(reading.sentence.contains("Left row"))
        #expect(reading.sentence.contains("Right row"))
    }

    /// The field draws the caption at rest, speaks it in words and
    /// keeps its Go to as a named action.
    @Test("the field draws and speaks the caption")
    func fieldWiring() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Keybindings/Recorder/"
            )
        let read = { (name: String) throws -> String in
            SourceScan.stripComments(
                try String(
                    contentsOf: root.appendingPathComponent(name),
                    encoding: .utf8
                )
            ).filter { !$0.isWhitespace }
        }
        let field = try read("KeyRecorderField.swift")
        #expect(field.contains("deadCaptionnarrowingCaption"))
        #expect(field.contains("letnarrowing:SideNarrowing?"))
        let caption = try read("KeyRecorderField+Narrowing.swift")
        // At rest, and stepping aside for a row nothing runs.
        #expect(caption.contains("if!recording,!isDead,letnarrowing,"))
        #expect(caption.contains(".accessibilityLabel(words.spoken)"))
        // The Go to is a VoiceOver action only where it is drawn.
        #expect(
            caption.contains(
                "GoToAction(title:Self.goToTitle,"
                    + "live:coordinator.scrollsInPlace)"
            )
        )
        #expect(caption.contains("iflive{content.accessibilityAction("))
        #expect(caption.contains("coordinator.scrollTarget=row"))
    }

    /// Every recorder mount over a layer hands its row's narrowing;
    /// `nil` compiles, so the silent direction is needled (#3256).
    @Test("each mount hands the row its narrowing")
    func mountsHandTheNarrowing() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings/Components")
        let read = { (path: String) throws -> String in
            SourceScan.stripComments(
                try String(
                    contentsOf: root.appendingPathComponent(path),
                    encoding: .utf8
                )
            ).filter { !$0.isWhitespace }
        }
        for path in [
            "Keybindings/KeybindingAppGroup+Row.swift",
            "Keybindings/PocketAppRows.swift",
            "Lua/AdvancedLuaGroup+Row.swift",
        ] {
            #expect(
                try read(path).contains("narrowing:SideNarrowing.of("),
                "\(path)"
            )
        }
        let nav = try read("Keybindings/KeybindingNavRow.swift")
        #expect(nav.contains("narrowing:SideNarrowing.of("))
        #expect(nav.contains("narrowing:drawn.narrowing,"))
        // The one exemption: a sequence's own rows.
        #expect(
            try read("Keybindings/Sequences/SequenceNodeRow+Recorder.swift")
                .contains("narrowing:nil,")
        )
        // The reading comes through the layer's memo.
        let caption = try read(
            "Keybindings/Recorder/KeyRecorderField+Narrowing.swift"
        )
        #expect(caption.contains("LayerConflictMemo.reach("))
    }
}
