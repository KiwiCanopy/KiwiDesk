import Foundation

/// Envelope for palettes.json with schema format versioning
/// (#939). The format integer is homed HERE, on the file's ROOT
/// type — never on `ColorPalette`, which also travels inside
/// `SetupBundle`, where the bundle's own format governs (#945).
struct PaletteDocument: Codable {
    /// Format version of palettes.json schema (0 = legacy bare array, #939).
    static let currentFormat = 1

    /// Decoded format version preserved without normalization (#945).
    var format: Int
    var palettes: [ColorPalette]

    enum CodingKeys: String, CodingKey {
        case format
        case palettes
    }

    init(
        format: Int = PaletteDocument.currentFormat,
        palettes: [ColorPalette]
    ) {
        self.format = format
        self.palettes = palettes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        let decodedFormat =
            try container.decodeIfPresent(
                Int.self,
                forKey: .format
            ) ?? 0
        guard decodedFormat <= Self.currentFormat else {
            throw DecodingError.dataCorruptedError(
                forKey: .format,
                in: container,
                debugDescription:
                    "palette format \(decodedFormat) is newer "
                    + "than supported \(Self.currentFormat)"
            )
        }
        format = decodedFormat
        palettes =
            try container.decodeIfPresent(
                [ColorPalette].self,
                forKey: .palettes
            ) ?? []
    }
}
