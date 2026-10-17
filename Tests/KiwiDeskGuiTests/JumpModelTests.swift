import AppKit
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// How the Jump to window panel's keys move it (#1875 ▸ keys):
/// Esc clears a query before it closes, Return and ⌘ digits pick,
/// and VoiceOver hears the selection and the result count.
@Suite("Jump to window model")
@MainActor
struct JumpModelTests {
    private func model() -> JumpModel {
        let entries = [
            JumpListTests.row(1, "Ghostty", "~/Desktop"),
            JumpListTests.row(2, "Mail", "Inbox"),
            JumpListTests.row(3, "Notes", "Ideas"),
        ]
        let model = JumpModel(
            snapshot: JumpSnapshot(
                entries: entries,
                here: "1",
                hereIcon: nil
            ),
            icons: [:],
            rowCap: 6,
            pointer: .zero
        )
        model.currentPointer = { .zero }
        return model
    }

    @Test("Esc clears a query, then closes")
    func escape() {
        let model = model()
        var closed = 0
        model.onClose = { closed += 1 }
        model.query = "mail"
        model.handle(.escape)
        #expect(model.query == "")
        #expect(closed == 0)
        model.handle(.escape)
        #expect(closed == 1)
    }

    @Test("Return picks the selection, ⌘ digits pick by result")
    func picks() {
        let model = model()
        var picked: [(String, Bool)] = []
        model.onPick = { picked.append(($0.app, $1)) }
        model.handle(.pick(moveHere: false))
        model.handle(.quick(2, moveHere: true))
        model.handle(.quick(5, moveHere: false))
        #expect(picked.map(\.0) == ["Ghostty", "Notes"])
        #expect(picked.map(\.1) == [false, true])
    }

    @Test("a page moves the selection by the visible rows")
    func paging() {
        let entries = (1...20).map {
            JumpListTests.row(UInt32($0), "App \($0)")
        }
        let model = JumpModel(
            snapshot: JumpSnapshot(
                entries: entries,
                here: "1",
                hereIcon: nil
            ),
            icons: [:],
            rowCap: 6,
            pointer: .zero
        )
        #expect(model.list.selection == 0)
        model.handle(.page(1))
        #expect(model.list.selection == 6)
        model.handle(.page(1))
        #expect(model.list.selection == 12)
        model.handle(.page(-1))
        #expect(model.list.selection == 6)
    }

    @Test("VoiceOver hears the selection and the result count")
    func announcements() {
        LocalizationManager.shared.select("en")
        let model = model()
        var heard: [String] = []
        model.onAnnounce = { heard.append($0) }
        model.handle(.step(1))
        model.handle(.step(1))
        // At the end: nothing moved, nothing said.
        model.handle(.step(1))
        model.query = "zzz"
        model.query = "no"
        #expect(
            heard == [
                "Mail, Inbox, Space 1",
                "Notes, Ideas, Space 1",
                "No open windows match",
                "Results: 1",
            ]
        )
    }

    @Test("⌘ and ⇧ are read from the held modifiers")
    func modifiers() {
        let model = model()
        model.noteModifiers([.command, .shift])
        #expect(model.commandHeld && model.shiftHeld)
        model.noteModifiers([])
        #expect(!model.commandHeld && !model.shiftHeld)
    }
}
