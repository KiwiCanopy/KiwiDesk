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
        look([
            "kiwishelf.edge": .string("bottom"),
            "border.sheen": .number(0),
            "space_bar.active_indicator": .string("edge_mark"),
        ]).apply(to: &settings)
        #expect(settings.kiwishelf.edge == .bottom)
        #expect(settings.borderStyle.sheen == 0)
        #expect(settings.spaceBarStyle.activeIndicator == .edgeMark)
        #expect(settings.kiwishelf.cornerRoundness == 80)
        #expect(
            ColorPaletteKeys.extract(from: settings)
                == ColorPaletteKeys.extract(from: TilingSettings())
        )
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
