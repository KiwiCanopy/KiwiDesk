import Foundation
import Testing

@testable import KiwiDeskCore

/// One-shot look application (#1684): sparse, routed through the
/// commands' own setters, colours only when a palette is handed in.
@Suite("Shelf look apply")
struct ShelfLookApplyTests {
    private func look(_ style: [String: JSONValue]) -> ShelfLook {
        ShelfLook(name: "T", palette: nil, style: style)
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
            palette: "Slate",
            style: [
                "kiwishelf.edge": .string("bottom"),
                "border.sheen": .number(0),
                "space_bar.active_indicator": .string("edge_mark"),
            ]
        )
        named.apply(to: &settings)
        #expect(settings.kiwishelf.edge == .bottom)
        #expect(settings.borderStyle.sheen == 0)
        #expect(settings.spaceBarStyle.activeIndicator == .edgeMark)
        #expect(settings.kiwishelf.cornerRoundness == 80)
        // Colours move only when a palette is handed in — never
        // the look's own, which names one.
        #expect(
            ColorPaletteKeys.extract(from: settings)
                == ColorPaletteKeys.extract(from: before)
        )
        // Undo the three named fields: nothing else moved.
        settings.kiwishelf.edge = before.kiwishelf.edge
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
            "kiwishelf.edge": .string("diagonal"),
            "kiwishelf.fill_color": .string("#FF0000"),
            "app_bar.content": .string("icon"),
            "nonsense": .bool(true),
        ]).apply(to: &settings)
        #expect(settings == TilingSettings())
    }

    @Test("a handed-in palette paints after the styling")
    func paletteApplies() {
        var settings = TilingSettings()
        let palette = ColorPalette(
            name: "P",
            colors: ["kiwishelf.fill_color": "#112233"]
        )
        look(["kiwishelf.edge": .string("left")])
            .apply(to: &settings, palette: palette)
        #expect(settings.kiwishelf.fillColor == "#112233")
        #expect(settings.kiwishelf.edge == .left)
    }

    /// A saved look captures the config's wire spellings and
    /// applies them through the command parsers; the two
    /// vocabularies must agree on every path, off the defaults too.
    @Test("a look saved from any styling reproduces it")
    func savedLookRoundTrips() {
        var source = TilingSettings()
        source.kiwishelf.edge = .left
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
        let saved = ShelfLook(
            name: "T",
            palette: nil,
            style: LookKeys.extract(from: source)
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
            palette: nil,
            style: LookKeys.extract(from: settings)
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
        let taskbar = look(["kiwishelf.edge": .string("bottom")])
        #expect(!taskbar.isApplied(to: settings))
        taskbar.apply(to: &settings)
        #expect(taskbar.isApplied(to: settings))
        #expect(!look([:]).isApplied(to: settings))
    }
}
