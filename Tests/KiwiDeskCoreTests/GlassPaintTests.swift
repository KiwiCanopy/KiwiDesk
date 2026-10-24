import AppKit
import Testing

@testable import KiwiDeskCore

/// **SwiftUI glass takes the Fill through the one mint** (#2569):
/// `GlassTint.paint` hands KiwiHub and the cue plates the same
/// capped colours, fade and dark pin the AppKit painter draws, in
/// SwiftUI's y-down unit space.
@Suite("Glass paint for SwiftUI (#2569)")
@MainActor
struct GlassPaintTests {
    /// Reduce transparency is pinned off (#660, #1374).
    init() { LiquidGlassGate.override = { false } }

    private static var drawsGlass: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }

    @Test("The paint carries the capped ends and the fade")
    func paintCarriesTheEnds() throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        let paint = try #require(
            GlassTint.paint(GlassFill(hex: "#FF0000FF", fade: 100), edge: .top)
        )
        #expect(abs(paint.anchorAlpha - Double(GlassTint.maxAlpha)) < 0.001)
        #expect(
            abs(paint.farAlpha - paint.anchorAlpha * GlassTint.floorShare)
                < 0.001
        )
        #expect(paint.red > 0.99 && paint.green < 0.01)
        let even = try #require(
            GlassTint.paint(GlassFill(hex: "#FF0000FF", fade: 0), edge: .top)
        )
        #expect(even.anchorAlpha == even.farAlpha)
    }

    /// SwiftUI's unit points grow DOWN; a top fade starts at y 0.
    @Test("The top fade runs downward in SwiftUI's space")
    func topFadeRunsDown() throws {
        try #require(Self.drawsGlass, "no glass below macOS 26")
        let paint = try #require(
            GlassTint.paint(GlassFill(hex: "#14201CB3"), edge: .top)
        )
        #expect(paint.start == CGPoint(x: 0.5, y: 0))
        #expect(paint.end == CGPoint(x: 0.5, y: 1))
        #expect(paint.pinsDark)
        let light = try #require(
            GlassTint.paint(GlassFill(hex: "#F2F2F7B3"), edge: .top)
        )
        #expect(!light.pinsDark)
    }

    @Test("No colour, no paint")
    func noColourNoPaint() {
        #expect(GlassTint.paint(GlassFill(hex: ""), edge: .top) == nil)
        LiquidGlassGate.override = { true }
        defer { LiquidGlassGate.override = { false } }
        #expect(
            GlassTint.paint(GlassFill(hex: "#14201CB3"), edge: .top) == nil
        )
    }

    /// KiwiHub's and the cues' inks — the system labels and
    /// KiwiHub's selection on the hover fill — hold the reading
    /// floor at the strongest fade (#2569 ▸ Ruling).
    @Test("KiwiHub's inks hold the reading floor", arguments: [false, true])
    func hubInksHoldTheFloor(darkPick: Bool) throws {
        for palette in PaletteCatalog.bundled() {
            var settings = TilingSettings()
            palette.apply(to: &settings)
            var shelf = settings.kiwishelf
            shelf.fillFade = 100
            let fill = shelf.panelGlassFill(
                darkPick: darkPick,
                increaseContrast: false
            )
            let rgba = try #require(DragVisual.parseHex(shelf.fillColor))
            let anchor = min(CGFloat(rgba.alpha), GlassTint.maxAlpha)
            let share = max(GlassTint.farShare(fade: 100), fill.minShare)
            let ground = shelf.fill(cappedAt: anchor * share)
            let inks = shelf.panelInks(darkPick: darkPick)
            try #require(inks.count == 3)
            for (ink, layer) in inks {
                let value = try #require(
                    shelf.worstContrast(ink, nil, on: ground, beneath: layer)
                )
                // Where the Fill's own anchor cannot hold it, the
                // floor is the whole anchor and nothing fades.
                #expect(
                    value >= KiwiShelf.readingInkFloor - 0.01
                        || fill.minShare == 1,
                    "\(palette.name) \(ink): \(value)"
                )
            }
        }
    }
}
