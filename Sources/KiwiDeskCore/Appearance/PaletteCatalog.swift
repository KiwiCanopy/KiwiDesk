import Foundation

/// Built-in and default color palette provider (`ColorPaletteTests`, #375).
public enum PaletteCatalog {
    /// The name of the always-present default palette.
    public static let defaultName = "Kiwi (Default)"

    /// Neon showcase palette name (#358, #578).
    public static let neonName = "Kiwi Neon"

    /// All nine built-ins, default first.
    public static func bundled() -> [ColorPalette] {
        [defaultPalette()] + authored()
    }

    /// The default palette: the current shipped color defaults,
    /// extracted from a fresh `TilingSettings`.
    public static func defaultPalette() -> ColorPalette {
        ColorPalette(
            name: defaultName,
            colors: ColorPaletteKeys.extract(from: TilingSettings())
        )
    }

    /// The eight authored palettes from `Resources/Palettes`.
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
        return palettes
    }
}
