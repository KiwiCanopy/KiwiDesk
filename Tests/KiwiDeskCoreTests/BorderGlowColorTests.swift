import Testing

@testable import KiwiDeskCore

/// The derived glow-bloom color (#358): a bloom is a fill, not a
/// legibility-bound stroke, so it brightens the ring hue instead of
/// reusing the darkened stroke verbatim. Hue-preserving; saturation
/// floored, lightness lifted.
@Suite("Border glow color")
struct BorderGlowColorTests {
    @Test("Default ring blooms a vivid lime")
    func defaultDerivation() {
        // #588613 (H84 S75 L30) → S floored to .80, L lifted to .55.
        #expect(
            BorderStyle.glowColor(from: "#588613") == "#9FE830"
        )
    }

    @Test("Hue is preserved — a blue ring blooms blue")
    func huePreserved() {
        let glow = BorderStyle.glowColor(from: "#0A84FF")
        let c = DragVisual.parseHex(glow)
        #expect(c != nil)
        guard let c else { return }
        // Still blue-dominant (no drift toward green), and lighter
        // than the input's lightness.
        #expect(c.blue >= c.green)
        #expect(c.blue > c.red)
        #expect(c.red > 0.2)  // lifted off the dark input
    }

    @Test("Unparseable input passes through unchanged")
    func parseFailPassthrough() {
        #expect(BorderStyle.glowColor(from: "not-a-hex") == "not-a-hex")
    }
}
