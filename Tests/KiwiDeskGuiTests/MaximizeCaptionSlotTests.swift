import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Both Maximize captions, bound and unbound, place their link
/// (#3062) — the assertion `CrossReferenceRowSlotTests` registers
/// their call sites against.
@Suite("Maximize caption link position (#3062)")
@MainActor
struct MaximizeCaptionSlotTests {
    @Test func maximizeCaptionsPlaceTheirLinks() {
        for prose in [
            MaximizeChordCaption.prose(name: "Height", chord: "⌃⌥⇧M"),
            MaximizeChordCaption.prose(name: "Width", chord: nil),
            MaximizeShareCaption.prose(axis: .height),
            MaximizeShareCaption.prose(axis: .width),
        ] {
            #expect(prose.contains(CrossReferenceRow.linkSlot), "\(prose)")
        }
    }
}
