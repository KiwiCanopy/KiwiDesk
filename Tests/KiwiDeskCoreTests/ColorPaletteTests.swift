import Foundation
import Testing

@testable import KiwiDeskCore

/// The palette color model (#375): the reflection-derived color-key
/// surface, one-shot apply through the shared field setters, the
/// derived default palette, and the bundled catalog. Pure — no GUI.
@Suite("Color palette")
struct ColorPaletteTests {
    /// A distinct valid hex per index (unique first byte).
    private func hex(_ i: Int) -> String {
        String(
            format: "#%02X%02X%02X",
            (i + 1) & 0xFF,
            (i * 7 + 3) & 0xFF,
            (i * 13 + 5) & 0xFF
        )
    }

    @Test("The color surface is the 27 namespaced color paths")
    func colorSurface() {
        let all = ColorPaletteKeys.all
        #expect(all.count == 27)
        #expect(all.allSatisfy { $0.contains(".") })
        // Every path is a color key.
        #expect(all.allSatisfy { $0.hasSuffix("_color") })
        // A colliding wire key appears once per bar, disambiguated.
        #expect(all.contains("app_bar.box_color"))
        #expect(all.contains("space_bar.box_color"))
        // Space-only key present; border + both drag elements too.
        #expect(all.contains("space_bar.focused_item_color"))
        #expect(all.contains("border.focused_color"))
        #expect(all.contains("drag.ghost.fill_color"))
        #expect(all.contains("drag.drop_zone.border_color"))
    }

    @Test("Apply writes every color path (parity via encode)")
    func applyCoversEveryPath() throws {
        // A palette that sets EVERY path to a distinct hex, applied
        // to fresh settings, must land each hex at its path — a path
        // the apply switch forgets would fail to change. Read back
        // by encoding, so no field is hand-listed here.
        let paths = ColorPaletteKeys.all
        var colors: [String: String] = [:]
        for (i, path) in paths.enumerated() {
            colors[path] = hex(i)
        }
        var settings = TilingSettings()
        ColorPalette(name: "T", colors: colors).apply(to: &settings)
        let readBack = ColorPaletteKeys.extract(from: settings)
        for (i, path) in paths.enumerated() {
            #expect(
                readBack[path] == hex(i),
                "path \(path) not applied"
            )
        }
    }

    @Test("The default palette equals the shipped color defaults")
    func defaultPaletteIsDefaults() {
        let def = PaletteCatalog.defaultPalette()
        #expect(def.name == PaletteCatalog.defaultName)
        #expect(
            def.colors
                == ColorPaletteKeys.extract(
                    from: TilingSettings()
                )
        )
        #expect(def.colors.count == 27)
    }

    @Test("Applying the default palette restores default colors")
    func defaultPaletteRestores() {
        var settings = TilingSettings()
        settings.appBarStyle.boxColor = "#123456"
        settings.spaceBarStyle.textColor = "#654321"
        settings.borderStyle.focusedColor = "#ABCDEF"
        PaletteCatalog.defaultPalette().apply(to: &settings)
        let fresh = TilingSettings()
        #expect(settings.appBarStyle.boxColor == fresh.appBarStyle.boxColor)
        #expect(
            settings.spaceBarStyle.textColor
                == fresh.spaceBarStyle.textColor
        )
        #expect(
            settings.borderStyle.focusedColor
                == fresh.borderStyle.focusedColor
        )
    }

    @Test("A sparse palette leaves absent colors untouched")
    func sparseApply() {
        var settings = TilingSettings()
        let before = settings.spaceBarStyle.textColor
        ColorPalette(
            name: "S",
            colors: ["app_bar.box_color": "#111111"]
        ).apply(to: &settings)
        #expect(settings.appBarStyle.boxColor == "#111111")
        // An untouched key keeps its value.
        #expect(settings.spaceBarStyle.textColor == before)
    }

    @Test("An invalid hex or unknown path is skipped, not fatal")
    func skipsBadInput() {
        var settings = TilingSettings()
        let before = settings.appBarStyle.boxColor
        ColorPalette(
            name: "X",
            colors: [
                "app_bar.box_color": "not-a-hex",
                "app_bar.nonsense_color": "#222222",
                "made_up.path.deep": "#333333",
            ]
        ).apply(to: &settings)
        #expect(settings.appBarStyle.boxColor == before)
    }

    @Test("The bundled catalog is 7 palettes, default first, unique")
    func bundledCatalog() {
        let all = PaletteCatalog.bundled()
        #expect(all.count == 7)
        #expect(all.first?.name == PaletteCatalog.defaultName)
        let names = all.map(\.name)
        #expect(Set(names).count == 7)
        // The six authored palettes decoded from the resource.
        #expect(PaletteCatalog.authored().count == 6)
    }

    @Test("Every bundled palette's colors are valid hexes")
    func bundledColorsValid() {
        for palette in PaletteCatalog.bundled() {
            for (path, hex) in palette.colors {
                #expect(
                    ColorPaletteKeys.all.contains(path),
                    "\(palette.name): unknown path \(path)"
                )
                #expect(
                    DragVisual.parseHex(hex) != nil,
                    "\(palette.name): bad hex \(hex) at \(path)"
                )
            }
        }
    }

    @Test("A palette round-trips through JSON")
    func roundTrip() throws {
        let palette = ColorPalette(
            name: "Mine",
            colors: ["border.focused_color": "#FF0000"]
        )
        let data = try JSONEncoder().encode(palette)
        let back = try JSONDecoder().decode(
            ColorPalette.self,
            from: data
        )
        #expect(back == palette)
    }
}
