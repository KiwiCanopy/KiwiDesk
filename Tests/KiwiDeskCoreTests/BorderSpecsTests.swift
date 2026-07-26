import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The pure "who gets a ring" decision (#278,
/// `KiwiCore.borderSpecs`): focused always; every other visible
/// tiled slot when `unfocusedEnabled` and not monocle, including
/// every member of an overflow cascade.
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
        overlays: Set<WindowID> = [],
        fullscreen: Set<WindowID> = [],
        monocle: Bool = false
    ) -> [BorderManager.Spec] {
        KiwiCore.borderSpecs(
            style: style,
            focused: focused,
            slots: slots,
            floating: floating,
            overlays: overlays,
            fullscreen: fullscreen,
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

    @Test("Glow rides the focused ring only, never unfocused")
    func glowFocusedOnly() {
        var style = BorderStyle()
        style.glow = true
        style.unfocusedEnabled = true
        let result = specs(style, focused: w1, slots: disjoint)
        let focused = result.first { $0.window == w1 }
        let other = result.first { $0.window == w2 }
        #expect(
            focused?.glowBlur == style.resolvedGlowBlur
        )
        #expect((focused?.glowBlur ?? 0) > 0)
        // A bloom on every unfocused ring would undercut the one it
        // should make pop (#358) — so unfocused rings never glow.
        #expect(other?.glowBlur == 0)
        // And with glow off, the focused ring doesn't glow either.
        style.glow = false
        let plain = specs(style, focused: w1, slots: disjoint)
        #expect(plain.first { $0.window == w1 }?.glowBlur == 0)
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
        // w2 floats and heavily overlaps the focused tiled w1, but
        // gets no unfocused ring of its own.
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

    @Test("A focused transient overlay gets no ring")
    func focusedOverlaySuppressed() {
        // A launcher (Spotlight/Raycast) momentarily takes focus.
        // It floats and is classified an overlay, so it gets no
        // focus ring even though it is the focused window.
        #expect(
            specs(
                BorderStyle(),
                focused: w1,
                slots: disjoint,
                floating: [w1],
                overlays: [w1]
            ).isEmpty
        )
    }

    @Test("A focused user-floated window still gets a ring")
    func focusedFloatStillRinged() {
        // A user-floated *standard* window (float rule, not an
        // overlay) keeps its focus ring — only overlays lose it.
        let result = specs(
            BorderStyle(),
            focused: w1,
            slots: disjoint,
            floating: [w1],
            overlays: []
        )
        #expect(result.map(\.window) == [w1])
    }

    @Test("An overlay is excluded from unfocused rings too")
    func overlayExcludedWhenUnfocused() {
        var style = BorderStyle()
        style.unfocusedEnabled = true
        // w2 is an unfocused overlay; w1 focused, w3 a tiled slot.
        let slots: [(id: WindowID, frame: CGRect)] = [
            (w1, CGRect(x: 0, y: 0, width: 100, height: 100)),
            (w2, CGRect(x: 10, y: 10, width: 100, height: 100)),
            (w3, CGRect(x: 400, y: 0, width: 100, height: 100)),
        ]
        let result = specs(
            style,
            focused: w1,
            slots: slots,
            floating: [w2],
            overlays: [w2]
        )
        #expect(Set(result.map(\.window)) == [w1, w3])
    }

    @Test("A focused native-fullscreen window gets no ring")
    func focusedFullscreenSuppressed() {
        // A display-filling window would show a ring only at its
        // rounded corners — suppress it (jankyborders does too).
        // A normal focused window keeps its ring (`focusedOnly`).
        #expect(
            specs(
                BorderStyle(),
                focused: w1,
                slots: disjoint,
                fullscreen: [w1]
            ).isEmpty
        )
    }

    @Test("A fullscreen window is excluded from unfocused rings")
    func fullscreenExcludedWhenUnfocused() {
        var style = BorderStyle()
        style.unfocusedEnabled = true
        // w2 is fullscreen; its home-space slot survives (no
        // destroy fires on the green button), but it must not
        // wear an unfocused ring while w1 and w3 keep theirs.
        let slots: [(id: WindowID, frame: CGRect)] = [
            (w1, CGRect(x: 0, y: 0, width: 100, height: 100)),
            (w2, CGRect(x: 200, y: 0, width: 100, height: 100)),
            (w3, CGRect(x: 400, y: 0, width: 100, height: 100)),
        ]
        let result = specs(
            style,
            focused: w1,
            slots: slots,
            fullscreen: [w2]
        )
        #expect(Set(result.map(\.window)) == [w1, w3])
    }

    @Test("Every overflow cascade member gets a ring")
    func cascadeMembersRemainIndependent() {
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
        #expect(Set(result.map(\.window)) == [w1, w2, w3])
        #expect(
            result.first { $0.window == w2 }?.colorHex
                == style.unfocusedColor
        )
    }
}
