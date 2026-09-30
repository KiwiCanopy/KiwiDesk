import Foundation
import Testing

@testable import KiwiDeskCore

/// The one dedupe every GUI writer of layer rows takes (#1807): per
/// navigation action, a Space verb's own digit is kept, else the
/// first; an orphan Space verb and a `custom` row are never removed.
@Suite("Navigation chords (#1807)")
struct NavigationChordsTests {
    private func row(
        _ combo: String,
        _ lua: String,
        kind: KeyBinding.Kind = .navigation
    ) -> KeyBinding {
        KeyBinding(combo: combo, lua: lua, kind: kind, label: "")
    }

    private let live: Set<SpaceID> = [SpaceID("1"), SpaceID("5")]

    @Test("a Space verb keeps its own digit, wherever it sits")
    func spaceVerbKeepsOwnDigit() {
        let rows = [
            row("control+option+f5", "KiwiDesk.focus_space(\"5\")"),
            row("control+option+5", "KiwiDesk.focus_space(5)"),
        ]
        let result = NavigationChords.deduplicated(rows, liveSpaces: live)
        #expect(result.rows.map(\.combo) == ["control+option+5"])
        #expect(result.dropped.first?.kept.combo == "control+option+5")
        #expect(result.dropped.first?.dropped.combo == "control+option+f5")
    }

    @Test("any other navigation action keeps its first chord")
    func otherActionKeepsFirst() {
        let rows = [
            row("control+option+left", "KiwiDesk.focus(\"left\")"),
            row("control+option+h", "KiwiDesk.focus(\"left\")"),
            row("control+option+right", "KiwiDesk.focus(\"right\")"),
        ]
        let result = NavigationChords.deduplicated(rows, liveSpaces: live)
        #expect(
            result.rows.map(\.combo) == [
                "control+option+left", "control+option+right",
            ]
        )
    }

    @Test("an orphan Space verb and a custom row are never removed")
    func orphanAndCustomStay() {
        let rows = [
            row("control+option+7", "KiwiDesk.focus_space(\"7\")"),
            row("control+option+f7", "KiwiDesk.focus_space(\"7\")"),
            row("control+option+1", "KiwiDesk.focus_space(\"1\")"),
            row(
                "control+option+f1",
                "KiwiDesk.focus_space(\"1\")",
                kind: .custom
            ),
        ]
        let result = NavigationChords.deduplicated(rows, liveSpaces: live)
        #expect(result.rows.count == 4)
        #expect(result.dropped.isEmpty)
    }
}
