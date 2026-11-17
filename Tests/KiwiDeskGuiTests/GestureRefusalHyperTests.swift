import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The two-key refusal names Hyper as a way out only while a Hyper
/// key is set; with none set it says Hyper waits for one (#3407).
@MainActor
@Suite("Gesture refusal names Hyper by its state")
struct GestureRefusalHyperTests {
    @Test("the two-key sentence follows whether a Hyper key is set")
    func sentenceFollowsTheKey() {
        LocalizationManager.shared.select("en")
        let on = GestureRefusalWords.sentence(
            .singleModifierScroll,
            hyperOff: false
        )
        let off = GestureRefusalWords.sentence(
            .singleModifierScroll,
            hyperOff: true
        )
        #expect(on != off)
        #expect(on.contains("or Hyper"))
        #expect(off.contains("once a Hyper key is set"))
    }

    @Test("the row hands the sentence the mount's Hyper reading")
    func rowReadsTheModel() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Gestures/"
                    + "GestureListRow.swift"
            )
        let source = try SourceScan.strippedSource(at: file)
        #expect(
            source.contains("@Environment(\\.hyperKeyIsOff) var hyperOff")
        )
        // Every sentence the row asks for hands the mount's reading.
        let asks =
            source.components(separatedBy: "GestureRefusalWords.sentence(")
            .count - 1
        let handed =
            source.components(separatedBy: "hyperOff: hyperOff").count - 1
        #expect(asks > 0)
        #expect(handed == asks)
    }
}
