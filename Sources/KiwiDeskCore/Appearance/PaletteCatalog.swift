import Foundation

/// Built-in and default color palette provider (#375). The default
/// is DERIVED from the shipped struct defaults at load, so it
/// always equals reset-to-default and cannot drift.
public enum PaletteCatalog {
    /// The name of the always-present default palette.
    public static let defaultName = "Kiwi (Default)"

    /// Neon showcase palette name (#358) — color-only like every
    /// palette; the glow pairing is a GUI link keyed on this name,
    /// never a side-effect (#578). Must match `bundled.json`
    /// (`ColorPaletteTests`).
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
