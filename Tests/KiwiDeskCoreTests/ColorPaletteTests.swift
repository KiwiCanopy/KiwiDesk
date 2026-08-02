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

    @Test("The color surface is the 25 namespaced color paths")
    func colorSurface() {
        let all = ColorPaletteKeys.all
        #expect(all.count == 25)
        #expect(all.allSatisfy { $0.contains(".") })
        // Every path is a color key: `_color`-suffixed, or the
        // bare `color` of a struct that IS one mark.
        #expect(
            all.allSatisfy {
                $0.hasSuffix("_color") || $0.hasSuffix(".color")
            }
        )
        // A colliding wire key appears once per bar, disambiguated.
        #expect(all.contains("app_bar.fill_color"))
        #expect(all.contains("space_bar.fill_color"))
        // Space-only key present; border + both drag elements too.
        #expect(all.contains("space_bar.focused_item_color"))
        #expect(all.contains("border.focused_color"))
        #expect(all.contains("drag.ghost.fill_color"))
        #expect(all.contains("drag.drop_zone.border_color"))
        // The two mark tints joined in the #678 Colours phase, so
        // Advanced Colours' "save these as a palette" bridge
        // carries every row it shows.
        #expect(all.contains("sticky.color"))
        #expect(all.contains("floating.color"))
    }

    /// Only the mark paths admit the empty "Automatic" value, and
    /// the predicate is derived from the path shape rather than
    /// hand-listed — a `_color` path taking an empty value would
    /// write an unrenderable color.
    @Test("Automatic is a mark-only palette value")
    func automaticIsMarkOnly() {
        let automatic = ColorPaletteKeys.all.filter(
            ColorPaletteKeys.allowsAutomatic
        )
        #expect(Set(automatic) == ["sticky.color", "floating.color"])
    }

    /// Both directions: a palette paints a mark, and a palette
    /// hands it back to Automatic. The second half is what the
    /// hex-only guard used to drop — the derived default palette
    /// extracts the shipped defaults, and both of those are empty.
    @Test("A mark tint round-trips through Automatic")
    func markTintRoundTrips() {
        var settings = TilingSettings()
        ColorPalette(
            name: "M",
            colors: [
                "sticky.color": "#8B5E3C",
                "floating.color": "#4A9816",
            ]
        ).apply(to: &settings)
        #expect(settings.stickyStyle.color == "#8B5E3C")
        #expect(settings.floatingStyle.color == "#4A9816")

        PaletteCatalog.defaultPalette().apply(to: &settings)
        #expect(settings.stickyStyle.color.isEmpty)
        #expect(settings.floatingStyle.color.isEmpty)
    }

    /// The empty value stays mark-only at the APPLY seam too, not
    /// merely in the predicate: an empty hex aimed at a `_color`
    /// path is skipped, so no palette can blank a bar color.
    @Test("An empty hex is skipped on a non-mark path")
    func emptyHexSkippedElsewhere() {
        var settings = TilingSettings()
        let before = settings.appBarStyle.fillColor
        ColorPalette(
            name: "E",
            colors: ["app_bar.fill_color": ""]
        ).apply(to: &settings)
        #expect(settings.appBarStyle.fillColor == before)
        #expect(!before.isEmpty)
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
        #expect(def.colors.count == 25)
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

    @Test("The bundled catalog is 9 palettes, default first, unique")
    func bundledCatalog() {
        let all = PaletteCatalog.bundled()
        #expect(all.count == 9)
        #expect(all.first?.name == PaletteCatalog.defaultName)
        let names = all.map(\.name)
        #expect(Set(names).count == 9)
        // The eight authored palettes decoded from the resource.
        #expect(PaletteCatalog.authored().count == 8)
        // The neon showcase palette exists under its shared name —
        // the GUI keys its swatch's "pair with Glow" link on it
        // (#578, replacing the retracted glow-on-select side-effect).
        #expect(names.contains(PaletteCatalog.neonName))
    }

    @Test("Every bundled palette's colors are valid hexes")
    func bundledColorsValid() {
        for palette in PaletteCatalog.bundled() {
            for (path, hex) in palette.colors {
                #expect(
                    ColorPaletteKeys.all.contains(path),
                    "\(palette.name): unknown path \(path)"
                )
                // Empty is the mark tints' "Automatic" face and
                // is legal only there — the derived default
                // palette carries both of them empty.
                #expect(
                    DragVisual.parseHex(hex) != nil
                        || (hex.isEmpty
                            && ColorPaletteKeys.allowsAutomatic(
                                path
                            )),
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
