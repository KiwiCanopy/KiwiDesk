import AppKit
import Testing

@testable import KiwiDeskCore

/// A refusal pill wraps rather than cut its sentence (owner,
/// 2026-11-08): on a narrow window such as Calculator the Tile
/// refusal showed about half its words. Up to
/// `SizeLimitPillPlate.maxLines` lines; past that the last ends
/// in "…".
@Suite("Size limit pill wrap")
struct SizeLimitPillWrapTests {
    private let long =
        "Can't tile: Windows that can't be resized float "
        + "automatically. Change it in App Rules."

    private var oneLine: CGFloat {
        SizeLimitPillPlate.textHeight("Can't tile", width: 1000)
    }

    @Test("a short sentence keeps one line")
    func shortKeepsOneLine() {
        let text = SizeLimitPillPlate.textHeight(
            "Can't be any smaller",
            width: 400
        )
        #expect(text == oneLine)
    }

    @Test("a long sentence on a narrow pill wraps")
    func longWraps() {
        let text = SizeLimitPillPlate.textHeight(long, width: 176)
        #expect(text > oneLine * 1.5)
        #expect(text <= oneLine * CGFloat(SizeLimitPillPlate.maxLines))
    }

    @Test("wrapping stops at the line cap")
    func capped() {
        let text = SizeLimitPillPlate.textHeight(
            String(repeating: long + " ", count: 6),
            width: 120
        )
        #expect(text <= oneLine * CGFloat(SizeLimitPillPlate.maxLines))
        #expect(text > oneLine * 2.5)
    }

    /// The overlay's own call site: a long refusal flashed on a
    /// Calculator-sized window draws a taller plate, a short one
    /// on a wide window keeps the one-line height.
    @Test("a flashed long refusal draws a taller pill")
    @MainActor
    func flashedPillGrows() throws {
        let overlay = SizeLimitOverlay()
        try #require(
            overlay.flash(
                window: 1,
                frame: CGRect(x: 200, y: 200, width: 230, height: 400),
                text: long,
                symbol: "nosign"
            )
        )
        try #require(
            overlay.flash(
                window: 2,
                frame: CGRect(x: 200, y: 200, width: 800, height: 600),
                text: "Can't be any smaller",
                symbol: "nosign"
            )
        )
        let tall = try #require(overlay.pillForTest(1)).plate.frame
        let short = try #require(overlay.pillForTest(2)).plate.frame
        #expect(short.height == SizeLimitPillPlate.lineHeight)
        #expect(tall.height > SizeLimitPillPlate.lineHeight)
        #expect(tall.width <= 230 - 24)
    }

    @Test("a wrapped pill holds longer")
    func wrappedHoldsLonger() {
        let one = SizeLimitOverlay.hold(
            height: SizeLimitPillPlate.lineHeight
        )
        let three = SizeLimitOverlay.hold(
            height: SizeLimitPillPlate.lineHeight + 28
        )
        #expect(three > one)
    }

    @Test("the Tile refusal pill leads with the refused act")
    @MainActor
    func pillLeads() {
        for reason in [AutoFloatReason.fixedSize, .accessoryApp, .panel] {
            #expect(reason.pillSentence.hasPrefix("Can't tile: "))
            #expect(reason.pillSentence.hasSuffix(reason.sentence))
        }
    }
}
