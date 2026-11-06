import Foundation
import SwiftUI
import Testing

@testable import KiwiDesk

/// A tile or card answers the pointer with `hoverEdge` and the shared
/// rise (#3042), its selection kept apart by a heavier stroke, staying
/// flat where a click changes nothing, and a check where the stroke
/// alone marked it. Each clause pins one surface's adoption.
@Suite("Hover rise adoption")
struct HoverRiseAdoptionTests {
    private func squashed(_ path: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
            .appendingPathComponent(path)
        let text = try String(contentsOf: url, encoding: .utf8)
        // A vanished file would pass every negative needle.
        #expect(text.count > 200, Comment(rawValue: path))
        return SourceScan.stripComments(text)
            .split(whereSeparator: \.isWhitespace).joined()
    }

    @Test("every tile and card takes the one rise, and no fill lift")
    func surfacesAdopt() throws {
        for (path, needle) in [
            ("HomeCard.swift", ".hoverRise(hovering,in:"),
            ("Components/Layouts/LayoutStrip.swift", ".hoverRise(risen,in:"),
            ("Components/Looks/PaletteTile.swift", ".hoverRise(risen,in:"),
            ("Components/Screens/ScreenCard.swift", ".hoverRise(risen,in:"),
            (
                "Components/Gestures/GestureStripHoverCue.swift",
                ".hoverRise(hovering,in:"
            ),
        ] {
            let source = try squashed(path)
            #expect(source.contains(needle), Comment(rawValue: path))
            #expect(
                source.contains("SettingsTheme.hoverEdge"),
                Comment(rawValue: path)
            )
            #expect(
                source.contains("SettingsTheme.hoverEdgeStroke")
                    || path.hasSuffix("ScreenCard.swift"),
                Comment(rawValue: path)
            )
            #expect(!source.contains("chipRest"), Comment(rawValue: path))
        }
    }

    /// `offset` before `contentShape`: a hit area that rose with the
    /// card would let a pointer on its bottom edge fall out, drop the
    /// card and re-enter, which flickers.
    @Test("the hit area stays where the card rests")
    func hitAreaStaysAtRest() throws {
        let rise = try squashed("HoverRise.swift")
        let offset = try #require(rise.range(of: ".offset(y:risen?"))
        let shape = try #require(rise.range(of: ".contentShape(shape)"))
        #expect(offset.upperBound < shape.lowerBound)
    }

    /// Where a click changes nothing a selected surface stays flat;
    /// a Screen card's click deselects, so it rises (owner rulings
    /// 2026-10-17, #3042).
    @Test("selection decides who rises")
    func selectionDecidesTheRise() throws {
        #expect(
            try squashed("Components/Layouts/LayoutStrip.swift").contains(
                "letrisen=hovered==mode&&isEnabled&&!selected"
            )
        )
        #expect(
            try squashed("Components/Looks/PaletteTile.swift").contains(
                "varrisen:Bool{hovered&&isEnabled&&!isApplied}"
            )
        )
        let screen = try squashed("Components/Screens/ScreenCard.swift")
        #expect(
            screen.contains("varrisen:Bool{hovering&&isEnabled&&!targeted}")
        )
        #expect(screen.contains(".onHover{hovering=$0}"))
    }

    /// The pointer's stroke stays under every selected one: in dark
    /// the two are one colour, so weight is what remains on a still
    /// frame.
    @Test("a selected stroke outweighs the hover edge")
    func selectedOutweighsHover() {
        let hover = SettingsTheme.hoverEdgeStroke
        #expect(hover < SettingsTheme.paletteCardStrokeApplied)
        #expect(hover < SettingsTheme.screenCardStrokeSelected)
    }

    /// A Layout tile's stroke was its whole selection mark, which now
    /// shares a colour with the pointer's in dark.
    @Test("a selected Layout tile carries a check")
    func layoutTileCarriesACheck() throws {
        let strip = try squashed("Components/Layouts/LayoutStrip.swift")
        #expect(
            strip.contains("systemImage:selected?\"checkmark\":mode.symbol")
        )
        #expect(strip.contains("lineWidth:selected?2:risen?SettingsTheme."))
    }

    /// A scroller clips what leaves its bounds, a risen tile's top and
    /// its shadow, so the shared strip keeps room for both.
    @Test("a sideways strip leaves room for the rise")
    func stripLeavesRoom() throws {
        let strip = try squashed("Components/Common/SidewaysStrip.swift")
        #expect(strip.contains(".padding(.top,SettingsTheme.hoverRise)"))
        #expect(
            strip.contains(
                ".padding(.bottom,SettingsTheme.hoverRiseShadowRoom)"
            )
        )
    }

    /// The gesture plate is light in light mode alone, so this pairing
    /// sits outside the two-appearance contrast table.
    @Test("the hover edge clears the light plate")
    func edgeClearsTheLightPlate() throws {
        let ratio = try ThemeContrast.contrast(
            SettingsTheme.hoverEdge,
            over: SettingsTheme.lightPlate,
            layers: [],
            wash: nil,
            inkAlpha: 1,
            dark: false
        )
        #expect(ratio >= 3.0)
    }
}
