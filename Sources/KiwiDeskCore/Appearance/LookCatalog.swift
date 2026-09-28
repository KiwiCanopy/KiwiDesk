import Foundation

/// The bundled looks (#1684). Glass is DERIVED from the shipped
/// defaults, as the default palette is, so it never drifts and
/// doubles as the shape reset; every other bundled look is Glass
/// with its authored differences laid over it, so each names the
/// whole of `LookKeys` and reproduces its picture wherever it is
/// applied.
public enum LookCatalog {
    /// The always-present default look.
    public static let defaultName = "Glass"

    /// Every built-in, Glass first.
    public static func bundled() -> [ShelfLook] {
        let glass = defaultLook()
        return [glass]
            + authored().map { look in
                ShelfLook(
                    name: look.name,
                    palette: look.palette,
                    style: glass.style.merging(look.style) { $1 }
                )
            }
    }

    /// Glass: the shipped styling defaults in the default palette.
    public static func defaultLook() -> ShelfLook {
        ShelfLook(
            name: defaultName,
            palette: PaletteCatalog.defaultName,
            style: LookKeys.extract(from: TilingSettings())
        )
    }

    /// The authored differences from `Resources/Looks`.
    static func authored() -> [ShelfLook] {
        guard
            let url = Bundle.kiwiDeskCore.url(
                forResource: "bundled",
                withExtension: "json",
                subdirectory: "Looks"
            ),
            let data = try? Data(contentsOf: url),
            let looks = try? JSONDecoder().decode(
                [ShelfLook].self,
                from: data
            )
        else { return [] }
        return looks
    }
}
