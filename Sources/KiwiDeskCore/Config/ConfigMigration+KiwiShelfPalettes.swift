import Foundation

/// The palette half of the shelf crossing (#1517,
/// `KiwiShelfPaletteMigrationTests`): a palette's bar colours
/// become `kiwishelf.*` — the Space Bar's, its dimmed idle ink
/// resolved to the App Bar's full colour — and every other bar
/// copy drops. Reaches `palettes.json` below format 2 and a
/// bundle's inline palettes below the bundle's shelf format. The
/// exported sidecar has no stamp, so its import runs
/// `shelvedPaletteColors` in memory instead (profiles.md).
extension ConfigMigration {
    /// The palette format this step introduced, spelled as
    /// history.
    static let shelfPaletteFormat = 2
    static let shelfPalettesKey = "palettes"
    static let shelfColorsKey = "colors"

    @Sendable
    static func migratingPalettesOntoShelf(_ data: Data) -> Data? {
        guard
            let root = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any],
            var palettes = root[shelfPalettesKey] as? [[String: Any]]
        else { return nil }
        let format = root["format"] as? Int ?? 0
        let floor =
            root[SetupBundle.shapeMarker] != nil
            ? shelfBundleFormat : shelfPaletteFormat
        guard format < floor else { return nil }
        var changed = false
        for index in palettes.indices {
            guard
                let colors = palettes[index][shelfColorsKey]
                    as? [String: String]
            else { continue }
            let shelved = shelvedPaletteColors(colors)
            guard shelved != colors else { continue }
            palettes[index][shelfColorsKey] = shelved
            changed = true
        }
        guard changed else { return nil }
        var out = root
        out[shelfPalettesKey] = palettes
        return try? JSONSerialization.data(
            withJSONObject: out,
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    /// One palette's colour map with the bars' shared colours on
    /// the shelf. Pure, and idempotent on a shelved map.
    public static func shelvedPaletteColors(
        _ colors: [String: String]
    ) -> [String: String] {
        var out = colors
        let shared = shelfMovedKeys.filter { $0.hasSuffix("_color") }
        for key in shared {
            let space = colors["\(shelfSpaceBarKey).\(key)"]
            let app = colors["\(shelfAppBarKey).\(key)"]
            out["\(shelfSpaceBarKey).\(key)"] = nil
            out["\(shelfAppBarKey).\(key)"] = nil
            let target = "\(shelfKey).\(key)"
            guard out[target] == nil else { continue }
            if key == shelfItemColorKey, let space, let app,
                isDimmedTwin(space, of: app)
            {
                out[target] = app
            } else if let value = space ?? app {
                out[target] = value
            }
        }
        return out
    }
}
