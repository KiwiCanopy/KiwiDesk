import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The CLI's human lines for a `delete_space` whose Space comes
/// back on the next load (#1509): one per `declared_in` source,
/// none for any other payload.
@Suite("CLI declared_in notes (#1509)")
struct CLIDeclaredInNoteTests {
    private func payload(_ sources: [String]) -> JSONValue {
        .object([
            "declared_in": .array(sources.map { .string($0) })
        ])
    }

    @Test("each source gets its own line, in payload order")
    func oneLinePerSource() {
        let notes = CLIOutput.declaredInNotes(
            payload([
                "profile:Work", "standard:Developer", "init.lua",
                "gui.json",
            ])
        )
        #expect(
            notes == [
                "still declared in profile \"Work\" — "
                    + "save the profile to make this durable",
                "still composed by the built-in \"Developer\" "
                    + "standard — save a profile to make this durable",
                "still created by init.lua — "
                    + "remove the call that creates it",
                "still listed in gui.json — remove it in Settings",
            ]
        )
    }

    @Test("a payload without the key prints nothing")
    func otherPayloadsAreSilent() {
        let other = JSONValue.object(["space_id": .string("3")])
        #expect(CLIOutput.declaredInNotes(other).isEmpty)
        #expect(CLIOutput.declaredInNotes(.null).isEmpty)
    }

    /// A source this CLI does not know is still said, never
    /// swallowed — the hint's promise is every re-creator.
    @Test("an unknown source is named rather than dropped")
    func unknownSourceIsNamed() {
        #expect(
            CLIOutput.declaredInNotes(payload(["elsewhere"]))
                == ["still declared in elsewhere"]
        )
    }
}
