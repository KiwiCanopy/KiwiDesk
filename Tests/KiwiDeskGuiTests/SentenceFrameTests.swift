import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The app-rule sentence's word order belongs to the
/// translation, not to the `HStack` (#678 turn 14a).
///
/// An earlier cut emitted the connectives as their own keys
/// between fixed stack positions, which is the harm
/// `.claude/rules/localization.md` names by title: a
/// translation cannot reorder pieces stitched together in
/// Swift. This app ships ja, ko, zh-Hans and zh-Hant, and a
/// verb-final language cannot put "opens in" where an English
/// stack puts it — so no catalog edit could have produced a
/// grammatical row.
@Suite("Sentence frame")
struct SentenceFrameTests {
    private func slots(_ format: String) -> [SentenceFrame.Slot] {
        SentenceFrame(format).segments.map(\.slot)
    }

    @Test("literal text and argument slots split in order")
    func splitsInOrder() {
        #expect(
            slots("%1$@ opens in %2$@ and %3$@") == [
                .argument(1),
                .text(" opens in "),
                .argument(2),
                .text(" and "),
                .argument(3),
            ]
        )
    }

    /// The whole point: a translation that moves the verb to the
    /// end is emitted in ITS order, not re-sorted into English.
    @Test("a reordered translation keeps its own order")
    func verbFinalOrderSurvives() {
        #expect(
            slots("%1$@ は %2$@ で開き、%3$@") == [
                .argument(1),
                .text(" は "),
                .argument(2),
                .text(" で開き、"),
                .argument(3),
            ]
        )
        // And a frame that leads with a control rather than
        // text — nothing assumes the sentence starts with words.
        #expect(slots("%2$@: %1$@").first == .argument(2))
    }

    /// Every argument the view draws must survive the round
    /// trip, whatever order they arrive in.
    @Test("argument positions are reported as written")
    func argumentPositions() {
        #expect(
            SentenceFrame("%3$@ %1$@ %2$@").argumentPositions
                == [3, 1, 2]
        )
    }

    /// A literal percent is not a specifier and must not eat the
    /// text after it — the shape a "50% width" string would take.
    @Test("a bare percent stays literal")
    func barePercentIsLiteral() {
        #expect(
            slots("50% of %1$@") == [
                .text("50% of "), .argument(1),
            ]
        )
    }

    /// An unknown position is kept verbatim rather than dropped.
    /// A catalog carrying `%4$@` for a three-argument frame is a
    /// translation bug, and showing it is how it gets noticed
    /// instead of silently losing a word.
    @Test("an out-of-range specifier is not silently dropped")
    func unknownArgumentSurvives() {
        let positions = SentenceFrame("%1$@ and %4$@")
            .argumentPositions
        #expect(positions == [1, 4])
    }

    /// The shipped English frame draws exactly the three
    /// controls the row has, each once — a frame that lost one
    /// would drop a menu off the row entirely.
    @Test("the shipped frame carries all three controls once")
    @MainActor
    func shippedFrameIsComplete() {
        let frame = SentenceFrame(
            L("app_rules.sentence", "%1$@ opens in %2$@ and %3$@")
        )
        #expect(frame.argumentPositions.sorted() == [1, 2, 3])
    }
}
