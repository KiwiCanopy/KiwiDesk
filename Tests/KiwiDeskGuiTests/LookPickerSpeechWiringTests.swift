import Foundation
import Testing

/// The look picker's card is VoiceOver's only element, and the
/// backdrop that closes on a click is hidden, so the card carries the
/// escape gesture as the close (#3698).
@Suite("Look picker speech wiring (#3698)")
struct LookPickerSpeechWiringTests {
    @Test("the card's escape action closes the picker")
    func escapeCloses() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/LookPicker/LookPickerRow.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        ).filter { !$0.isWhitespace }
        let subject = "privatestructLookPickerCardSpeech:ViewModifier{"
        let start = try #require(source.range(of: subject))
        let speech = source[start.upperBound...]
        #expect(
            speech.contains(
                ".accessibilityAction(.escape){"
                    + "model.handle(.escape,repeated:false)}"
            )
        )
        // The modifier is mounted on the card's seat.
        #expect(
            source.contains(".modifier(LookPickerCardSpeech(model:model))")
        )
    }
}
