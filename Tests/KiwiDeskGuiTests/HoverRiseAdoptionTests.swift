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
            (
                "Components/Looks/PaletteTile.swift",
                ".hoverRise(risen&&rises,in:"
            ),
            ("Components/Screens/ScreenCard.swift", ".hoverRise(risen,in:"),
            (
                "Components/Gestures/GestureStripHoverCue.swift",
                ".hoverRise(hovering,in:"
            ),
        ] {
            let source = try squashed(path)
            #expect(source.contains(needle), Comment(rawValue: path))
            // Followed by a non-identifier: `hoverEdgeStroke` must not
            // answer for the colour.
            #expect(
                source.contains(try Regex(#"SettingsTheme\.hoverEdge\W"#)),
                Comment(rawValue: path)
            )
            #expect(
                source.contains("SettingsTheme.hoverEdgeStroke"),
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
        // At rest the shadow's shape does not show.
        #expect(rise.contains(".opacity(risen?1:0)"))
    }

    /// `HoverRise` cannot own this: a `Button` label stops the trait.
    @Test("a surface over opaque siblings raises its own zIndex")
    func opaqueSurfacesTakeZIndex() throws {
        for (path, needle) in [
            ("HomeCard.swift", ".zIndex(hovering?1:0)"),
            (
                "Components/Layouts/LayoutStrip.swift",
                ".zIndex(hovered==mode?1:0)"
            ),
            ("Components/Screens/ScreenCard.swift", ".zIndex(risen?1:0)"),
            (
                "Components/Gestures/GestureStripHoverCue.swift",
                ".zIndex(hovering?1:0)"
            ),
        ] {
            #expect(
                try squashed(path).contains(needle),
                Comment(rawValue: path)
            )
        }
    }

    /// The tour's scrollers leave no room and its ground is `page`.
    @Test("the setup tour's tiles keep the edge and do not rise")
    func tourStaysDown() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Onboarding")
        let files = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "swift" }
        var tiles = 0
        for url in files {
            let text = SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            )
            let made = text.components(separatedBy: "PaletteTile(").count - 1
            tiles += made
            #expect(
                made == text.components(separatedBy: "rises: false").count - 1,
                Comment(rawValue: url.lastPathComponent)
            )
        }
        #expect(tiles > 0)
        #expect(
            try squashed("Components/Looks/PaletteTile.swift").contains(
                ".hoverRise(risen&&rises,in:"
            )
        )
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
        let check = try #require(
            strip.range(of: "Image(systemName:\"checkmark\")")
        )
        let name = try #require(
            strip.range(
                of: "Label(mode.displayName,systemImage:mode.symbol)"
            )
        )
        #expect(check.upperBound < name.lowerBound)
        // The slot stays, so the name never slides.
        #expect(
            strip.contains(
                ".frame(width:Self.checkSlot)"
                    + ".opacity(selected?1:0).selectionFade(selected)"
            )
        )
        #expect(strip.contains("lineWidth:risen?SettingsTheme."))
        #expect(strip.contains("risen?SettingsTheme.hoverEdge:"))
        #expect(
            strip.contains(
                "lineWidth:SettingsTheme.paletteCardStrokeApplied"
            )
        )
    }

    /// A selected stroke sits on its own layer so it fades, and a
    /// check fades with it, through the one gated animation.
    @Test("a selection's stroke and check fade in")
    func selectionFades() throws {
        for (path, selected) in [
            ("Components/Layouts/LayoutStrip.swift", "selected:selected"),
            ("Components/Looks/PaletteTile.swift", "selected:isApplied"),
            ("Components/Screens/ScreenCard.swift", "selected:isSelected"),
        ] {
            #expect(
                try squashed(path).contains("SelectionStroke(" + selected),
                Comment(rawValue: path)
            )
        }
        #expect(
            try squashed("Components/Looks/PaletteTile.swift").contains(
                ".opacity(isApplied?1:0).selectionFade(isApplied)"
            )
        )
        let stroke = try squashed("Components/Common/SelectionStroke.swift")
        #expect(
            stroke.contains(".opacity(selected?1:0).selectionFade(selected)")
        )
        #expect(stroke.contains("reduceMotion?nil:"))
        #expect(
            try squashed("Components/Screens/ScreenCard.swift").contains(
                "style:.tint,lineWidth:SettingsTheme.screenCardStrokeSelected"
            )
        )
    }

    /// A scroller clips what leaves its bounds, a risen tile's top and
    /// its shadow, so the shared strip keeps room for both.
    @Test("a sideways strip leaves room for the rise")
    func stripLeavesRoom() throws {
        let strip = try squashed("Components/Common/SidewaysStrip.swift")
        #expect(
            strip.contains(".padding(.top,SettingsTheme.hoverTopRoom)")
        )
        #expect(
            strip.contains("floor:SettingsTheme.hoverShadowRoom")
        )
    }

    /// The strip draws its run's end room, inside the clip and given
    /// back outside; each host states the room in its run.
    @Test("an end tile's shadow has room in every strip")
    func endTilesHaveRoom() throws {
        let strip = try squashed("Components/Common/SidewaysStrip.swift")
        #expect(strip.contains(".padding(.horizontal,run.endRoom)"))
        #expect(strip.contains(".padding(.horizontal,-run.endRoom)"))
        for path in [
            "Components/Gestures/GestureStrip.swift",
            "Components/Simple/SimpleLookCard.swift",
        ] {
            #expect(
                try squashed(path).contains("endRoom:endRoom"),
                Comment(rawValue: path)
            )
        }
    }

    /// Behind the card and tucked under its edge by what it rises.
    @Test("a risen Screen card opens no gap above its stand")
    func standTucksUnderTheCard() throws {
        let picture = try squashed("Components/Screens/ScreensPicture.swift")
        #expect(picture.contains(".background(alignment:.bottom){stand("))
        #expect(picture.contains("$0[.top]+SettingsTheme.hoverRise"))
        #expect(
            picture.contains(
                ".frame(width:neck,height:7+SettingsTheme.hoverRise)"
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
