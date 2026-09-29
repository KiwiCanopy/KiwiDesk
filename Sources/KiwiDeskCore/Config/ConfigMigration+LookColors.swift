import Foundation

/// A bundle's looks take in their palettes' colours (#1752). Pure,
/// unlike the library's carry: a bundle carries its user palettes
/// inline, so every name it can mean is in the bytes or bundled.
/// A name neither answers takes the shipped colours
/// (`LookColorCarry`), since a bundle has no live colours to give.
extension ConfigMigration {
    /// The bundle format that moved a look's colours into it.
    static let lookColorsBundleFormat = 17

    @Sendable
    static func migratingBundleLookColors(_ data: Data) -> Data? {
        guard
            let root = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any],
            root[SetupBundle.shapeMarker] != nil,
            root["format"] as? Int ?? 0 < lookColorsBundleFormat,
            let raw = root["looks"] as? [Any], !raw.isEmpty,
            let looks: [PaletteNamedLook] = decoded(raw)
        else { return nil }
        let inline: [ColorPalette] =
            (root["palettes"] as? [Any]).flatMap(decoded) ?? []
        let palettes = PaletteCatalog.bundled() + inline
        let carried = looks.map {
            LookColorCarry.carried($0, palettes: palettes)
        }
        guard
            let bytes = try? JSONEncoder().encode(carried),
            let json = try? JSONSerialization.jsonObject(with: bytes)
        else { return nil }
        var out = root
        out["looks"] = json
        return try? JSONSerialization.data(
            withJSONObject: out,
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    private static func decoded<T: Decodable>(_ raw: [Any]) -> [T]? {
        guard let bytes = try? JSONSerialization.data(withJSONObject: raw)
        else { return nil }
        return try? JSONDecoder().decode([T].self, from: bytes)
    }
}
