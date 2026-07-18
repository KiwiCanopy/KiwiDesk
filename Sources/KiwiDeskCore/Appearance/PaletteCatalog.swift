import Foundation

/// The built-in palettes (#375). "Kiwi (Default)" is derived from
/// the shipped struct defaults at load — so it always equals a
/// reset-to-default and never drifts from the real defaults — then
/// the six authored palettes come from the bundled resource. The
/// user-saved palettes live in `PaletteStore`, not here.
public enum PaletteCatalog {
    /// The name of the always-present default palette.
    public static let defaultName = "Kiwi (Default)"

    /// All seven built-ins, default first.
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

    /// The six authored palettes from `Resources/Palettes`.
    static func authored() -> [ColorPalette] {
        guard
            let url = Bundle.module.url(
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
