import Foundation

/// A look naming its palette rather than owning its colours: the
/// shape every look was saved in before #1752 — the library, a
/// bundle, an exported file — and the bundled looks' authored one,
/// which resolves at load so a palette retune reaches its looks.
struct PaletteNamedLook: Codable, Equatable {
    var name: String
    var palette: String?
    var style: [String: JSONValue]
}

/// Takes a look's colours out of the palette it named (#1752). A
/// byte-level `ConfigMigration` step cannot run it: the palette
/// library is another file. A name no palette answers — deleted,
/// or never set — takes the shipped colours, the one answer every
/// reader of the old shape can give alike.
enum LookColorCarry {
    static func carried(
        _ legacy: PaletteNamedLook,
        palettes: [ColorPalette]
    ) -> ShelfLook {
        let named = legacy.palette.flatMap { name in
            palettes.first { $0.name == name }
        }
        let palette = named ?? PaletteCatalog.defaultPalette()
        return ShelfLook(
            name: legacy.name,
            style: legacy.style,
            colors: palette.paintedColors
        )
    }

    /// `looks.json` bytes below format 2, carried against
    /// `palettes` and re-encoded at the current format; nil when
    /// the bytes are not an old library.
    static func carriedLibrary(
        _ data: Data,
        palettes: [ColorPalette]
    ) -> Data? {
        guard let old = try? JSONDecoder().decode(Legacy.self, from: data),
            old.format < LookDocument.currentFormat
        else { return nil }
        let looks = old.looks.map { carried($0, palettes: palettes) }
        return try? LookDocument.encoder.encode(
            LookDocument(looks: looks)
        )
    }

    /// Whether `data` is a look library below format 2 — cheap,
    /// ahead of reading the palette library the carry needs.
    static func isOwed(_ data: Data) -> Bool {
        guard
            let root = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any],
            root[LookDocument.CodingKeys.looks.rawValue] != nil
        else { return false }
        let format = root["format"] as? Int ?? 0
        return format < LookDocument.currentFormat
    }

    /// A look file exported before #1752, carried against the
    /// palette it travelled with, then `palettes`; nil when the
    /// bytes are not that shape.
    static func importedLegacy(
        _ data: Data,
        palettes: [ColorPalette]
    ) -> ShelfLook? {
        guard
            let file = try? JSONDecoder().decode(
                LegacyExport.self,
                from: data
            )
        else { return nil }
        let travelled = file.palette.map { [$0] } ?? []
        return carried(file.look, palettes: travelled + palettes)
    }

    private struct LegacyExport: Decodable {
        var look: PaletteNamedLook
        var palette: ColorPalette?
    }

    private struct Legacy: Decodable {
        var format: Int
        var looks: [PaletteNamedLook]

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: Key.self)
            format = try c.decodeIfPresent(Int.self, forKey: .format) ?? 0
            looks =
                try c.decodeIfPresent(
                    [PaletteNamedLook].self,
                    forKey: .looks
                ) ?? []
        }

        enum Key: String, CodingKey { case format, looks }
    }
}
