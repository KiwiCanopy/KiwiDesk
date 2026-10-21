import CoreGraphics
import Testing

@testable import KiwiDesk

/// A hover reading never leaves the panel: it shows every line
/// that fits and ends on a "more" line otherwise (#2532).
@Suite("Keyboard hover fit")
struct KeyboardHoverFitTests {
    @Test("every line shows when all fit")
    func allFit() {
        #expect(
            KeyboardHoverFit.shown(
                heights: [10, 10, 10],
                more: 10,
                spacing: 2,
                available: 34
            ) == 3
        )
    }

    @Test("an overflow keeps room for the more line")
    func overflowKeepsMore() {
        // Four lines need 46; 40 fits two lines and the more line.
        #expect(
            KeyboardHoverFit.shown(
                heights: [10, 10, 10, 10],
                more: 10,
                spacing: 2,
                available: 40
            ) == 2
        )
    }

    @Test("a wrapped line counts at its drawn height")
    func wrappedLineCounts() {
        #expect(
            KeyboardHoverFit.shown(
                heights: [10, 30, 10],
                more: 10,
                spacing: 2,
                available: 40
            ) == 1
        )
    }

    @Test("no room shows only the more line")
    func noRoom() {
        #expect(
            KeyboardHoverFit.shown(
                heights: [10, 10],
                more: 10,
                spacing: 2,
                available: 15
            ) == 0
        )
    }

    @Test("a longer line measures taller at a narrow width")
    func measuresWrapping() {
        let line = String(repeating: "Focus left ", count: 12)
        #expect(
            KeyboardHoverFit.height(of: line, width: 80)
                > KeyboardHoverFit.height(of: line, width: 2000)
        )
    }
}
