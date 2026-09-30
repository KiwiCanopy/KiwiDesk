import Foundation
import Testing

@testable import KiwiDeskCore

/// One-shot look application (#1684): sparse styling routed
/// through the commands' own setters, then the look's own colours
/// (#1752).
@Suite("Shelf look apply")
struct ShelfLookApplyTests {
    /// A look as every reader takes it (`ShelfLook.admitted`): the
    /// named styling in the shipped colours.
    private func look(_ style: [String: JSONValue]) -> ShelfLook {
        ShelfLook(name: "T", style: style, colors: [:]).admitted
    }

    @Test("a look sets what it names and nothing else")
    func sparse() {
        var settings = TilingSettings()
        settings.kiwishelf.cornerRoundness = 80
        settings.kiwishelf.fillColor = "#123456"
        settings.borderStyle.focusedColor = "#654321"
        let before = settings
        let named = ShelfLook(
            name: "T",
            style: [
                "space_bar.edge": .string("bottom"),
                "app_bar.edge": .string("left"),
                "border.sheen": .number(0),
                "space_bar.active_indicator": .string("edge_mark"),
            ],
            colors: [:]
        )
        named.apply(to: &settings)
        #expect(settings.spaceBarStyle.edge == .bottom)
        #expect(settings.appBarStyle.edge == .left)
        #expect(settings.borderStyle.sheen == 0)
        #expect(settings.spaceBarStyle.activeIndicator == .edgeMark)
        #expect(settings.kiwishelf.cornerRoundness == 80)
        // A look without colours of its own moves none.
        #expect(
            ColorPaletteKeys.extract(from: settings)
                == ColorPaletteKeys.extract(from: before)
        )
        // Undo the named fields: nothing else moved.
        settings.spaceBarStyle.edge = before.spaceBarStyle.edge
        settings.appBarStyle.edge = before.appBarStyle.edge
        settings.borderStyle.sheen = before.borderStyle.sheen
        settings.spaceBarStyle.activeIndicator =
            before.spaceBarStyle.activeIndicator
        #expect(settings == before)
    }

    @Test("values clamp exactly as their commands clamp")
    func clampsLikeTheCommands() {
        var settings = TilingSettings()
        look([
            "kiwishelf.thickness": .number(3),
            "kiwishelf.border_width": .number(40),
            "border.sheen": .number(9),
        ]).apply(to: &settings)
        #expect(settings.kiwishelf.thickness == KiwiShelf.minThickness)
        #expect(
            settings.kiwishelf.borderWidth
                == KiwiShelf.borderWidthRange.upperBound
        )
        #expect(settings.borderStyle.sheen == 1)
    }

    @Test("an unknown path or a refused value is skipped")
    func refusalsAreSkipped() {
        var settings = TilingSettings()
        look([
            "space_bar.edge": .string("diagonal"),
            "kiwishelf.fill_color": .string("#FF0000"),
            "app_bar.title_cap": .number(7),
            "nonsense": .bool(true),
        ]).apply(to: &settings)
        #expect(settings == TilingSettings())
    }

    @Test("a look paints its own colours after the styling")
    func coloursApply() {
        var settings = TilingSettings()
        var named = look(["app_bar.edge": .string("left")])
        named.colors = ["kiwishelf.fill_color": "#112233"]
        named.apply(to: &settings)
        #expect(settings.kiwishelf.fillColor == "#112233")
        #expect(settings.appBarStyle.edge == .left)
    }

    /// Colours compare by parsed value, the palette rule (#757):
    /// a lower-case hex and its upper-case, opaque-alpha twin are
    /// one colour.
    @Test("a look's colours match by parsed value")
    func coloursMatchByValue() {
        var settings = TilingSettings()
        settings.kiwishelf.fillColor = "#8DB354FF"
        var colors = ColorPaletteKeys.extract(from: settings)
        colors["kiwishelf.fill_color"] = "#8db354"
        let named = ShelfLook(
            name: "T",
            style: LookKeys.extract(from: settings),
            colors: colors
        )
        #expect(named.isApplied(to: settings))
    }

    /// The tile's three marks (#1752): the shape live in its own
    /// colours, the shape live in others, the shape not live.
    @Test("match tells other colours from applied and none")
    func matchReadsShapeThenColours() {
        var settings = TilingSettings()
        let named = ShelfLook(
            name: "T",
            style: LookKeys.extract(from: settings),
            colors: ColorPaletteKeys.extract(from: settings)
        )
        #expect(named.match(settings) == .applied)
        settings.kiwishelf.fillColor = "#010203"
        #expect(named.match(settings) == .otherColors)
        settings.spaceBarStyle.edge = .left
        #expect(named.match(settings) == .none)
    }

    /// A saved look captures the config's wire spellings and
    /// applies them through the command parsers; the two
    /// vocabularies must agree on every path, off the defaults too.
    @Test("a look saved from any styling reproduces it")
    func savedLookRoundTrips() {
        var source = TilingSettings()
        source.spaceBarStyle.edge = .left
        source.appBarStyle.edge = .bottom
        source.kiwishelf.alignment = .end
        source.kiwishelf.order = .appsFirst
        source.kiwishelf.thickness = 33
        source.kiwishelf.outerMargin = 5
        source.kiwishelf.innerMargin = 3
        source.kiwishelf.backgroundStyle = .boxed
        source.kiwishelf.backgroundFit = .full
        source.setLiquidGlass(false)
        source.kiwishelf.cornerRoundness = 20
        source.kiwishelf.border = true
        source.kiwishelf.borderWidth = 3
        source.kiwishelf.highlightWidth = 4
        source.kiwishelf.itemGap = 9
        source.kiwishelf.glyphSize = 30
        source.kiwishelf.fontSize = 13
        source.kiwishelf.fontFamily = "Geneva"
        source.kiwishelf.fontWeight = 700
        source.kiwishelf.iconSource = .appFont
        source.kiwishelf.dimFactor = 0.7
        source.spaceBarStyle.activeIndicator = .edgeMark
        source.spaceBarStyle.glyphGap = 2
        source.spaceBarStyle.activeDimFactor = 0.5
        source.appBarStyle.activeIndicator = .outline
        source.borderStyle.sheen = -0.25
        source.borderStyle.width = 7
        source.borderStyle.cornerStyle = .square
        source.borderStyle.glow = true
        source.borderStyle.glowSize = 12
        source.gapsGlobal = Gaps(
            outer: .init(top: 3, bottom: 4, left: 5, right: 6),
            inner: .init(horizontal: 7, vertical: 8)
        )
        let saved = ShelfLook(
            name: "T",
            style: LookKeys.extract(from: source),
            colors: [:]
        )
        var settings = TilingSettings()
        saved.apply(to: &settings)
        #expect(
            LookKeys.extract(from: settings)
                == LookKeys.extract(from: source)
        )
        // Every path is off its default, so none rides for free.
        let defaults = LookKeys.extract(from: TilingSettings())
        let written = LookKeys.extract(from: source)
        for path in LookKeys.all {
            #expect(written[path] != defaults[path], "\(path)")
        }
    }

    /// A look saved while the glass leaves disagree reads unapplied
    /// until clicked: "applied" means a click changes nothing.
    @Test("applied means a click would change nothing")
    func appliedMeansNoChange() {
        var settings = TilingSettings()
        settings.dragLiquidGlass = false
        let saved = ShelfLook(
            name: "T",
            style: LookKeys.extract(from: settings),
            colors: ColorPaletteKeys.extract(from: settings)
        )
        #expect(!saved.isApplied(to: settings))
        saved.apply(to: &settings)
        #expect(saved.isApplied(to: settings))
    }

    @Test("glass is one switch over every surface (#1307)")
    func glassWritesEveryLeaf() {
        var settings = TilingSettings()
        #expect(TilingSettings.liquidGlassLeaves.count > 1)
        look(["kiwishelf.liquid_glass": .bool(false)]).apply(to: &settings)
        for leaf in TilingSettings.liquidGlassLeaves {
            #expect(settings[keyPath: leaf] == false)
        }
    }

    @Test("the App Bar indicator is not hidden by a layout's")
    func indicatorClearsLayoutOverrides() {
        var settings = TilingSettings()
        // The two layouts cleared are every host there is; a third
        // host reds here until the look clears it too.
        #expect(settings.appBarHosts.count == 2)
        settings.monocle.appBar.activeIndicator = .outline
        settings.scrolling.appBar.activeIndicator = .outline
        let edge = look(["app_bar.active_indicator": .string("edge_mark")])
        #expect(!edge.isApplied(to: settings))
        edge.apply(to: &settings)
        #expect(settings.monocle.appBar.activeIndicator == nil)
        #expect(settings.scrolling.appBar.activeIndicator == nil)
        #expect(edge.isApplied(to: settings))
    }

    @Test("applied reads the styling, and an empty look never is")
    func appliedIsComputed() {
        var settings = TilingSettings()
        let taskbar = look([
            "space_bar.edge": .string("bottom"),
            "app_bar.edge": .string("bottom"),
        ])
        #expect(!taskbar.isApplied(to: settings))
        taskbar.apply(to: &settings)
        #expect(taskbar.isApplied(to: settings))
        #expect(!look([:]).isApplied(to: settings))
    }

    /// A look places the bars and never switches one: a bar that
    /// is off takes the look's edge and sits there once it is on
    /// again (#1731, owner 2026-09-28).
    @Test("a look sets an off bar's edge without switching it on")
    func edgesLeaveOnOffAlone() {
        var settings = TilingSettings()
        settings.spaceBarStyle.enabled = false
        settings.monocle.appBar.enabled = false
        look([
            "space_bar.edge": .string("left"),
            "app_bar.edge": .string("bottom"),
        ]).apply(to: &settings)
        #expect(!settings.spaceBarStyle.enabled)
        #expect(!settings.monocle.appBar.enabled)
        #expect(settings.spaceBarStyle.edge == .left)
        #expect(settings.appBarStyle.edge == .bottom)
    }
}
