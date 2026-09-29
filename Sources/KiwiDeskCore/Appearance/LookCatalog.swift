import CoreGraphics
import Foundation

/// The bundled looks (#1684). Glass is DERIVED from the starter's
/// tuning for the given screens, so it is what a first run shows
/// and doubles as the shape reset (#1739); every other bundled
/// look is Glass with its authored differences laid over it, so
/// each names the whole of `LookKeys` and reproduces its picture
/// wherever it is applied. Its colours are its authored palette's,
/// resolved at load (#1752).
public enum LookCatalog {
    /// The always-present default look.
    public static let defaultName = "Glass"

    /// Every built-in, Glass first, Glass derived for `sizes` —
    /// the screens in positional order (`StarterSetup.sizes`).
    /// Callers outside the catalog take `KiwiCore.bundledLooks`
    /// (`LookCatalogSeamTests`).
    public static func bundled(sizes: [CGSize]) -> [ShelfLook] {
        let glass = defaultLook(sizes: sizes)
        let palettes = PaletteCatalog.bundled()
        return [glass]
            + authored().map { authored in
                ShelfLook(
                    name: authored.name,
                    style: glass.style.merging(authored.style) { $1 },
                    colors: authored.colors(in: palettes)
                )
            }
    }

    /// Every built-in's name, which no screen changes.
    public static var bundledNames: [String] {
        [defaultName] + authored().map(\.name)
    }

    /// Glass: the starter's styling for `sizes` in the default
    /// palette, so a first run shows it (#1739). Reached through
    /// `KiwiCore.bundledLooks` (`LookCatalogSeamTests`).
    public static func defaultLook(sizes: [CGSize]) -> ShelfLook {
        ShelfLook(
            name: defaultName,
            style: LookKeys.extract(
                from: StarterSetup.settings(sizes: sizes)
            ),
            colors: PaletteCatalog.defaultPalette().paintedColors
        )
    }

    /// The authored differences from `Resources/Looks`, each
    /// naming its bundled palette.
    static func authored() -> [AuthoredLook] {
        guard
            let url = Bundle.kiwiDeskCore.url(
                forResource: "bundled",
                withExtension: "json",
                subdirectory: "Looks"
            ),
            let data = try? Data(contentsOf: url),
            let looks = try? JSONDecoder().decode(
                [AuthoredLook].self,
                from: data
            )
        else { return [] }
        return looks
    }
}

/// A bundled look as `Resources/Looks` authors it: its styling
/// differences and its paired palette by NAME, resolved at load so
/// a palette retune reaches the look (#1752).
struct AuthoredLook: Decodable {
    let name: String
    let palette: String
    let style: [String: JSONValue]

    /// The paired palette's colours over the shipped ones; a name
    /// no bundled palette answers gives the shipped colours, which
    /// `LookCatalogTests` ▸ `palettesExist` refuses to ship.
    func colors(in palettes: [ColorPalette]) -> [String: String] {
        let paired = palettes.first { $0.name == palette }
        return (paired ?? PaletteCatalog.defaultPalette()).paintedColors
    }
}
