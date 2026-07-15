import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The pure "who gets a ring" decision (#278,
/// `KiwiCore.borderSpecs`): focused always; every other visible
/// slot only when `unfocusedEnabled` and not monocle; overflow
/// piles collapse to one ring on their top window
/// (`Navigation.pileMates`).
@Suite("Border who-gets-a-ring")
struct BorderSpecsTests {
    private let w1 = WindowID(1)
    private let w2 = WindowID(2)
    private let w3 = WindowID(3)

    /// Two disjoint tiled slots plus a third far-away slot.
    private var disjoint: [(id: WindowID, frame: CGRect)] {
        [
            (w1, CGRect(x: 0, y: 0, width: 100, height: 100)),
            (w2, CGRect(x: 200, y: 0, width: 100, height: 100)),
        ]
    }

    private func specs(
        _ style: BorderStyle,
        focused: WindowID?,
        slots: [(id: WindowID, frame: CGRect)],
        floating: Set<WindowID> = [],
        monocle: Bool = false
    ) -> [BorderManager.Spec] {
        KiwiCore.borderSpecs(
            style: style,
            focused: focused,
            slots: slots,
            floating: floating,
            isMonocle: monocle
        )
    }

    @Test("Disabled borders yield nothing")
    func disabled() {
        var style = BorderStyle()
        style.enabled = false
        #expect(
            specs(style, focused: w1, slots: disjoint).isEmpty
        )
    }

    @Test("No focused window yields nothing")
    func noFocus() {
        #expect(
            specs(
                BorderStyle(),
                focused: nil,
                slots: disjoint
            ).isEmpty
        )
    }

    @Test("Focused-only: one ring in the focused color")
    func focusedOnly() {
        let result = specs(
            BorderStyle(),
            focused: w1,
            slots: disjoint
        )
        #expect(result.count == 1)
        #expect(result.first?.window == w1)
        #expect(
            result.first?.colorHex == BorderStyle().focusedColor
        )
    }

    @Test("Unfocused enabled: every disjoint slot gets a ring")
    func unfocusedRings() {
        var style = BorderStyle()
        style.unfocusedEnabled = true
        let result = specs(style, focused: w1, slots: disjoint)
        #expect(result.count == 2)
        #expect(result.first?.window == w1)
        let other = result.first { $0.window == w2 }
        #expect(other?.colorHex == style.unfocusedColor)
    }

    @Test("Monocle stays focused-only despite unfocused toggle")
    func monocleFocusedOnly() {
        var style = BorderStyle()
        style.unfocusedEnabled = true
        let result = specs(
            style,
            focused: w1,
            slots: disjoint,
            monocle: true
        )
        #expect(result.count == 1)
        #expect(result.first?.window == w1)
    }

    @Test("Floating windows are excluded from unfocused rings")
    func floatingExcluded() {
        var style = BorderStyle()
        style.unfocusedEnabled = true
        // w2 floats and heavily overlaps the focused tiled w1 — it
        // must NOT be treated as a pile mate (which would suppress
        // a ring) and gets no unfocused ring of its own.
        let slots: [(id: WindowID, frame: CGRect)] = [
            (w1, CGRect(x: 0, y: 0, width: 100, height: 100)),
            (w2, CGRect(x: 10, y: 10, width: 100, height: 100)),
            (w3, CGRect(x: 400, y: 0, width: 100, height: 100)),
        ]
        let result = specs(
            style,
            focused: w1,
            slots: slots,
            floating: [w2]
        )
        // Focused w1 + tiled w3; floating w2 neither rings nor
        // hides w3.
        #expect(Set(result.map(\.window)) == [w1, w3])
    }

    @Test("A pile gets one ring; buried mates are excluded")
    func pileCollapses() {
        var style = BorderStyle()
        style.unfocusedEnabled = true
        // w2 overlaps w1 heavily (a cascade mate); w3 is a
        // separate visible slot.
        let slots: [(id: WindowID, frame: CGRect)] = [
            (w1, CGRect(x: 0, y: 0, width: 100, height: 100)),
            (w2, CGRect(x: 10, y: 10, width: 100, height: 100)),
            (w3, CGRect(x: 400, y: 0, width: 100, height: 100)),
        ]
        let result = specs(style, focused: w1, slots: slots)
        // Focused w1 + the separate slot w3; buried w2 excluded.
        #expect(Set(result.map(\.window)) == [w1, w3])
    }
}
