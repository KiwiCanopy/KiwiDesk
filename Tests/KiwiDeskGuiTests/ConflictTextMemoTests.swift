import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Rows read their conflict through `LayerConflictMemo`, which takes
/// the layer's conflicts once per draft (#2783). A memo is only safe
/// while every input it reads moves it, so each case changes ONE
/// input after a read and requires the next read to match the
/// row-by-row check. Main-actor spend: a handful of tiny layers.
@Suite("A row's conflict reading is memoized safely", .serialized)
@MainActor
struct ConflictTextMemoTests {
    private func row(_ combo: String, _ lua: String) -> KeyBinding {
        KeyBinding(combo: combo, lua: lua, kind: .custom)
    }

    private func direct(
        _ binding: KeyBinding,
        _ rows: [KeyBinding],
        sides: Bool
    ) -> Conflict? {
        KeybindingConflicts.conflict(
            for: binding,
            in: rows,
            distinguishingSides: sides
        )
    }

    @Test("A combo another row takes after a read is seen")
    func comboEditMovesTheMemo() {
        var rows = [row("alt+h", "a()"), row("alt+j", "b()")]
        #expect(
            LayerConflictMemo.conflict(for: rows[0], in: rows, sides: false)
                == nil
        )
        rows[1].combo = "alt+h"
        let after = LayerConflictMemo.conflict(
            for: rows[0],
            in: rows,
            sides: false
        )
        #expect(after != nil)
        #expect(after == direct(rows[0], rows, sides: false))
    }

    @Test("The sides switch after a read is seen")
    func sidesMoveTheMemo() {
        let rows = [row("lcmd+j", "a()"), row("rcmd+j", "b()")]
        let off = LayerConflictMemo.conflict(
            for: rows[0],
            in: rows,
            sides: false
        )
        let on = LayerConflictMemo.conflict(
            for: rows[0],
            in: rows,
            sides: true
        )
        #expect(off == direct(rows[0], rows, sides: false))
        #expect(on == direct(rows[0], rows, sides: true))
        #expect(off != on)
    }

    @Test("A row that is not the layer's own is judged on its own")
    func foreignRowIsDirect() {
        let rows = [row("alt+h", "a()"), row("alt+j", "b()")]
        _ = LayerConflictMemo.conflict(for: rows[0], in: rows, sides: false)
        var edited = rows[0]
        edited.combo = "alt+j"
        let reading = LayerConflictMemo.conflict(
            for: edited,
            in: rows,
            sides: false
        )
        #expect(reading != nil)
        #expect(reading == direct(edited, rows, sides: false))
    }

    @Test("A layer holding one id twice is judged row by row")
    func duplicateIDIsDirect() {
        let first = row("alt+h", "a()")
        var twin = row("alt+j", "b()")
        twin.id = first.id
        let rows = [first, twin, row("alt+h", "c()")]
        let reading = LayerConflictMemo.conflict(
            for: first,
            in: rows,
            sides: false
        )
        #expect(reading == direct(first, rows, sides: false))
        let twinReading = LayerConflictMemo.conflict(
            for: twin,
            in: rows,
            sides: false
        )
        #expect(twinReading == direct(twin, rows, sides: false))
    }

    @Test("The reading every row surface takes reads the memo")
    func readingTakesTheMemo() throws {
        let path =
            "Sources/KiwiDesk/Settings/Components/Keybindings/"
            + "ConflictText.swift"
        let text = SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(path),
                encoding: .utf8
            )
        )
        let start = try #require(text.range(of: "static func reading("))
        let end = try #require(
            text.range(
                of: "static func tooltip(",
                range: start.upperBound..<text.endIndex
            )
        )
        let body = text[start.upperBound..<end.lowerBound]
        #expect(body.contains("LayerConflictMemo.conflict("))
        #expect(!body.contains("KeybindingConflicts."))
    }
}
