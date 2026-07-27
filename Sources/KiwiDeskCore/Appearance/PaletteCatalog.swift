import Foundation

/// The built-in palettes (#375). "Kiwi (Default)" is derived from
/// the shipped struct defaults at load — so it always equals a
/// reset-to-default and never drifts from the real defaults — then
/// the eight authored palettes come from the bundled resource. The
/// user-saved palettes live in `PaletteStore`, not here.
public enum PaletteCatalog {
    /// The name of the always-present default palette.
    public static let defaultName = "Kiwi (Default)"

    /// The neon showcase palette (#358 follow-up). Selecting it also
    /// switches the focus-ring glow on — the one bundled palette that
    /// carries a non-color behavior, applied by the GUI palette
    /// picker because palettes are otherwise color-only
    /// (`ColorPaletteKeys`). Must match its `name` in `bundled.json`;
    /// `ColorPaletteTests` guards that the entry exists.
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
