import Foundation

/// Built-in and default color palette provider (#375). The default
/// is DERIVED from the shipped struct defaults at load, with
/// `ColorPaletteKeys.bundledPaint` applied (#3377), so it cannot
/// drift.
public enum PaletteCatalog {
    /// The name of the always-present default palette.
    public static let defaultName = "Kiwi (Default)"

    /// Neon showcase palette name (#358) — color-only like every
    /// palette; the glow pairing is a GUI link keyed on this name,
    /// never a side-effect (#578). Must match `bundled.json`
    /// (`ColorPaletteTests`).
    public static let neonName = "Kiwi Neon"

    /// Every built-in, default first.
    public static func bundled() -> [ColorPalette] {
        [defaultPalette()] + authored()
    }

    /// The default palette: the current shipped color defaults,
    /// extracted from a fresh `TilingSettings`, with the handle
    /// painted in its accent as every bundled palette's is (#3377).
    public static func defaultPalette() -> ColorPalette {
        ColorPalette(
            name: defaultName,
            colors: ColorPaletteKeys.extract(from: TilingSettings())
        ).bundledPainted
    }

    /// The authored palettes from `Resources/Palettes`.
    static func authored() -> [ColorPalette] {
        guard
            let url = Bundle.kiwiDeskCore.url(
                forResource: "bundled",
                withExtension: "json",
                subdirectory: "Palettes"
            ),
            let data = try? Data(contentsOf: url),
            let palettes = try? JSONDecoder().decode(
                [ColorPalette].self,
                from: data
            )
        else { return [] }
        return palettes.map(\.bundledPainted)
    }
}

extension ColorPalette {
    /// This palette with each `ColorPaletteKeys.bundledPaint` path
    /// painted from its source colour — the one door every bundled
    /// palette and the starter take (#3377).
    var bundledPainted: ColorPalette {
        var out = self
        for (path, source) in ColorPaletteKeys.bundledPaint {
            if let colour = colors[source] { out.colors[path] = colour }
        }
        return out
    }
}

extension TilingSettings {
    /// Paints each `ColorPaletteKeys.bundledPaint` path from its
    /// source, as a bundled palette would: the starter's door, so a
    /// first run wears Glass whole (#3377, #1739).
    mutating func wearBundledPaint() {
        ColorPalette(
            name: "",
            colors: ColorPaletteKeys.extract(from: self)
        ).bundledPainted.apply(to: &self)
    }
}
