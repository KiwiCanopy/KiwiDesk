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

    @Test("The color surface is the 23 namespaced color paths")
    func colorSurface() {
        let all = ColorPaletteKeys.all
        #expect(all.count == 23)
        #expect(all.allSatisfy { $0.contains(".") })
        // Every path is a color key.
        #expect(all.allSatisfy { $0.hasSuffix("_color") })
        // A colliding wire key appears once per bar, disambiguated.
        #expect(all.contains("app_bar.fill_color"))
        #expect(all.contains("space_bar.fill_color"))
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
        #expect(def.colors.count == 23)
    }

    @Test("Applying the default palette restores default colors")
    func defaultPaletteRestores() {
        var settings = TilingSettings()
        settings.appBarStyle.fillColor = "#123456"
        settings.spaceBarStyle.itemColor = "#654321"
        settings.borderStyle.focusedColor = "#ABCDEF"
        PaletteCatalog.defaultPalette().apply(to: &settings)
        let fresh = TilingSettings()
        #expect(settings.appBarStyle.fillColor == fresh.appBarStyle.fillColor)
        #expect(
            settings.spaceBarStyle.itemColor
                == fresh.spaceBarStyle.itemColor
        )
        #expect(
            settings.borderStyle.focusedColor
                == fresh.borderStyle.focusedColor
        )
    }

    @Test("A sparse palette leaves absent colors untouched")
    func sparseApply() {
        var settings = TilingSettings()
        let before = settings.spaceBarStyle.itemColor
        ColorPalette(
            name: "S",
            colors: ["app_bar.fill_color": "#111111"]
        ).apply(to: &settings)
        #expect(settings.appBarStyle.fillColor == "#111111")
        // An untouched key keeps its value.
        #expect(settings.spaceBarStyle.itemColor == before)
    }

    @Test("An invalid hex or unknown path is skipped, not fatal")
    func skipsBadInput() {
        var settings = TilingSettings()
        let before = settings.appBarStyle.fillColor
        ColorPalette(
            name: "X",
            colors: [
                "app_bar.fill_color": "not-a-hex",
                "app_bar.nonsense_color": "#222222",
                "made_up.path.deep": "#333333",
            ]
        ).apply(to: &settings)
        #expect(settings.appBarStyle.fillColor == before)
    }

    @Test("The bundled catalog is 8 palettes, default first, unique")
    func bundledCatalog() {
        let all = PaletteCatalog.bundled()
        #expect(all.count == 8)
        #expect(all.first?.name == PaletteCatalog.defaultName)
        let names = all.map(\.name)
        #expect(Set(names).count == 8)
        // The seven authored palettes decoded from the resource.
        #expect(PaletteCatalog.authored().count == 7)
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

    @Test("Focused accent differs from the active accent")
    func focusedAccentDistinct() {
        // The two-accent rule applied to palette DATA
        // (QA 2026-07-19): an identical pair erases the
        // focused-window state (the original Monochrome
        // defect, #FFFFFF == #FFFFFF). Inequality, not hue
        // distance — cheap and catches the real failure.
        for palette in PaletteCatalog.bundled() {
            let focused =
                palette.colors["space_bar.focused_item_color"]
            let active =
                palette.colors["space_bar.active_item_color"]
            if let focused, let active {
                #expect(
                    focused.lowercased()
                        != active.lowercased(),
                    Comment(rawValue: palette.name)
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
