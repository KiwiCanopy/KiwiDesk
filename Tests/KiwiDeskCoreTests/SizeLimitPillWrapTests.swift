import AppKit
import Testing

@testable import KiwiDeskCore

/// A refusal pill wraps rather than cut its sentence (owner,
/// 2026-11-08): on a narrow window such as Calculator the Tile
/// refusal showed about half its words. Up to
/// `SizeLimitPillPlate.maxLines` lines; past that the last ends
/// in "…". The measure is the label cell's own, so these clauses
/// read the label as it draws.
@Suite("Size limit pill wrap")
@MainActor
struct SizeLimitPillWrapTests {
    private let long =
        "Can't tile. Windows that can't be resized float "
        + "automatically. Change it in App Rules."

    private func plate(_ text: String) -> SizeLimitPillPlate {
        let plate = SizeLimitPillPlate()
        plate.setSymbol("nosign")
        plate.setText(text)
        return plate
    }

    private func label(of plate: SizeLimitPillPlate) throws -> NSTextField {
        try #require(plate.subviews.compactMap { $0 as? NSTextField }.first)
    }

    @Test("a short sentence keeps the one-line pill")
    func shortKeepsOneLine() {
        let plate = plate("Can't be any smaller")
        #expect(plate.height(forWidth: 400) == SizeLimitPillPlate.lineHeight)
    }

    @Test("a long sentence on a narrow pill wraps")
    func longWraps() {
        let plate = plate(long)
        let line = plate.textLineHeight
        let text = plate.textHeight(forWidth: 206)
        #expect(text > line * 1.5)
        #expect(text <= line * CGFloat(SizeLimitPillPlate.maxLines))
        #expect(plate.height(forWidth: 206) > SizeLimitPillPlate.lineHeight)
    }

    @Test("wrapping stops at the line cap")
    func capped() {
        let plate = plate(String(repeating: long + " ", count: 6))
        let line = plate.textLineHeight
        let text = plate.textHeight(forWidth: 160)
        #expect(text <= line * CGFloat(SizeLimitPillPlate.maxLines))
        #expect(text > line * 2.5)
    }

    /// The label as drawn: it wraps, and at the plate's own laid
    /// out frame its cell needs no more height than it was given,
    /// so the last line is never cut before `maxLines`.
    @Test("the laid-out label holds its wrapped text")
    func labelHoldsText() throws {
        let plate = plate(long)
        let width: CGFloat = 206
        plate.frame = NSRect(
            x: 0,
            y: 0,
            width: width,
            height: plate.height(forWidth: width)
        )
        plate.layoutSubtreeIfNeeded()
        let label = try label(of: plate)
        #expect(label.maximumNumberOfLines == SizeLimitPillPlate.maxLines)
        #expect(label.lineBreakMode == .byWordWrapping)
        let cell = try #require(label.cell)
        let needs = cell.cellSize(
            forBounds: NSRect(
                x: 0,
                y: 0,
                width: label.frame.width,
                height: .greatestFiniteMagnitude
            )
        ).height
        #expect(needs <= label.frame.height + 0.5)
        #expect(label.frame.height > plate.textLineHeight * 1.5)
    }

    /// The overlay's own call site: a long refusal flashed on a
    /// Calculator-sized window draws a taller plate, a short one
    /// on a wide window keeps the one-line height.
    @Test("a flashed long refusal draws a taller pill")
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

    @Test("a wrapped pill holds a second longer per extra line")
    func wrappedHoldsLonger() {
        let one = SizeLimitOverlay.hold(extraLines: 0)
        #expect(SizeLimitOverlay.hold(extraLines: 2) == one + 2)
    }

    @Test("the Tile refusal pill leads with the refused act")
    func pillLeads() {
        // Asserts English words: pin the locale (#740, tests.md).
        LocalizationManager.shared.select("en")
        for reason in [AutoFloatReason.fixedSize, .accessoryApp, .panel] {
            #expect(reason.pillSentence.hasPrefix("Can't tile. "))
            #expect(reason.pillSentence.hasSuffix(reason.sentence))
        }
    }
}
