import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Fit layout gaps grows by the glow's resolved blur, ONCE, on the
/// focused side (#1378): the bloom rides the focused ring and only
/// one side of an inner gap is focused, so an unfocused ring adds
/// its stroke alone. Glow off leaves Fit byte-identical to #295's
/// arithmetic; a float rides the same reach.
@Suite("Fit layout gaps and the glow (#1378)")
struct FitGapsGlowTests {
    @Test("glow off leaves Fit byte-identical")
    func glowOffIsIdentical() {
        var style = BorderStyle()
        style.width = 10
        let off = style.fittingGaps(remaining: 3)
        style.glow = false
        style.glowSize = 30
        #expect(style.fittingGaps(remaining: 3) == off)
        #expect(off.outer.top == 13)
        #expect(off.inner.horizontal == 13)
    }

    @Test("auto glow grows Fit by the resolved blur at the default")
    func defaultWidthAutoGlow() {
        var style = BorderStyle()
        let plain = style.fittingGaps()
        #expect(plain.outer.top == style.clampedWidth)
        style.glow = true
        let fitted = style.fittingGaps()
        // Derived, not pinned: the width and the blur calibration
        // are the owner's numbers (`BorderGeometryTests`).
        let expected = (style.clampedWidth + style.resolvedGlowBlur)
            .rounded(.up)
        #expect(expected > plain.outer.top)
        #expect(fitted.outer.top == expected)
        #expect(fitted.inner.horizontal == expected)
        #expect(fitted.inner.vertical == expected)
    }

    @Test("the glow joins once: the unfocused ring adds its stroke")
    func unfocusedAddsStrokeOnly() {
        var style = BorderStyle()
        style.width = 10
        style.glow = true
        style.glowSize = 6
        style.unfocusedEnabled = true
        let gaps = style.fittingGaps(remaining: 2)
        // focused reach 16 + unfocused reach 10 + extra 2.
        #expect(gaps.inner.horizontal == 28)
        #expect(gaps.outer.top == 18)
    }

    @Test("a float keeps one glow off bars and edges too")
    @MainActor func floatInsetRidesTheReach() {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "kiwidesk-fit-glow-\(UUID().uuidString)"
                )
        )
        core.tiler.settings.borderStyle.width = 7
        core.tiler.settings.borderStyle.glow = false
        #expect(core.floatRingInset == 7)
        core.tiler.settings.borderStyle.glow = true
        core.tiler.settings.borderStyle.glowSize = 5
        #expect(core.floatRingInset == 12)
        // The automatic blur is fractional for most widths; the
        // inset rounds up as Fit does, so the two agree.
        core.tiler.settings.borderStyle.glowSize = 0
        let style = core.tiler.settings.borderStyle
        #expect(
            core.floatRingInset
                == style.fittingGaps().outer.top
        )
        #expect(
            core.floatRingInset == (7 + style.resolvedGlowBlur).rounded(.up)
        )
    }

    @Test("which ring blooms is one reading")
    func oneGlowHome() {
        var style = BorderStyle()
        style.glow = true
        style.glowSize = 6
        #expect(style.glowBlur(focused: true) == 6)
        #expect(style.glowBlur(focused: false) == 0)
        style.glow = false
        #expect(style.glowBlur(focused: true) == 0)
    }
}
