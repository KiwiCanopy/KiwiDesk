import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Sides pull-down's words and order (#2614): Left, Right, then
/// Either side, each side word the catalog's chord frame.
@Suite("Recorder Sides pull-down (#2614)")
@MainActor
struct KeyRecorderSidesTests {
    @Test("choices run Left, Right, Either side, in the chord's words")
    func choices() {
        LocalizationManager.shared.select("en")
        #expect(KeyRecorderField.choices == [.left, .right, nil])
        #expect(
            KeyRecorderField.choiceText(.left, kind: .command) == "Left ⌘"
        )
        #expect(
            KeyRecorderField.choiceText(.right, kind: .option) == "Right ⌥"
        )
        #expect(
            KeyRecorderField.choiceText(nil, kind: .shift) == "Either side"
        )
        #expect(KeyRecorderField.sectionTitle(.command) == "⌘ Command")
    }
}
